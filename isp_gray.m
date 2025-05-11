% -----------------------------
% 参数设置
% -----------------------------
fileName    = 'input.bin';       % 输入 RAW bin 文件名
width       = 1936;              % 帧宽
height      = 1088;              % 帧高
bytesPerPix = 2;                 % 每像素字节数（uint16 存储）
fps         = 30;                % 帧率

% 指定字节序：'ieee-be' 为大端，'ieee-le' 为小端
machineFormat = 'ieee-be';

% -----------------------------
% 打开文件（含字节序）
% -----------------------------
fid = fopen(fileName, 'rb', machineFormat);
if fid < 0
    error('无法打开文件 %s', fileName);
end

% 计算总帧数
fseek(fid, 0, 'eof');
fileSize      = ftell(fid);
bytesPerFrame = width * height * bytesPerPix;
numFrames     = floor(fileSize / bytesPerFrame);
fseek(fid, 0, 'bof');
fprintf('总文件大小：%d 字节，预计帧数：%d\n', fileSize, numFrames);

% -----------------------------
% 实时显示窗口
% -----------------------------
hFig = figure('Name','实时灰度视频','NumberTitle','off');
hAx  = axes('Parent', hFig);
hImg = imshow( zeros(height, width,'uint8'), 'Parent', hAx );
title(hAx, 'Raw 12-bit → 显示为 8-bit 灰度');

% -----------------------------
% 视频写入器
% -----------------------------
outputVideo = VideoWriter('output.avi','Motion JPEG AVI');
outputVideo.FrameRate = fps;
open(outputVideo);

% -----------------------------
% 主循环：读帧、显示、写入
% -----------------------------
for k = 1 : numFrames
    % 按指定字节序读取 uint16 数据
    raw = fread(fid, width*height, 'uint16=>uint16');
    if numel(raw) < width*height
        warning('读取不足一帧，提前结束。');
        break;
    end

    % 还原 12-bit（右移 4 位），并 reshape
    frame12 = bitshift(raw, -4);
    frame12 = reshape(frame12, [width, height])';  % 转置为 height×width

    % 缩放到 8-bit
    frame8 = uint8( double(frame12) / 4095 * 255 );

    % 实时更新显示
    set(hImg, 'CData', frame8);
    drawnow;

    % 写入视频
    writeVideo(outputVideo, frame8);
end

% -----------------------------
% 清理
% -----------------------------
fclose(fid);
close(outputVideo);
disp('视频保存完毕：output.avi');
