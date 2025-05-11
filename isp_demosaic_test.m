%% -----------------------------
% 全局参数
% -----------------------------
inFile       = 'day.bin';       % 输入 RAW 流
width        = 1936;              % 分辨率宽
height       = 1088;              % 分辨率高
bytesPerPix  = 2;                 % uint16 存储
machineFmt   = 'ieee-be';         % RAW 文件大小端
numFrames    = [];                % 若空，则自动计算
outputVideo  = 'demosaic.mp4';    % 输出视频文件
fps    = 30;                % 帧率

%% -----------------------------
% 打开 RAW 文件，计算帧数
% -----------------------------
fid = fopen(inFile, 'rb', machineFmt);
if fid < 0
    error('打开 RAW 文件失败：%s', inFile);
end
fseek(fid, 0, 'eof');
totalBytes = ftell(fid);
if isempty(numFrames)
    numFrames = floor(totalBytes / (width*height*bytesPerPix));
end
fseek(fid, 0, 'bof');
fprintf('总帧数：%d\n', numFrames);

%% -----------------------------
% 创建 VideoWriter（写入 8-bit 彩色视频）
% -----------------------------
vw = VideoWriter(outputVideo, 'MPEG-4');
vw.FrameRate = fps;
vw.Quality   = 90;
open(vw);

%% -----------------------------
% 循环读帧 → CFA 提取 → demosaic → 写入视频
% -----------------------------
for k = 1 : numFrames
    % 1) 读一帧 16-bit RAW
    raw16 = fread(fid, width*height, 'uint16=>uint16');
    if numel(raw16) < width*height
        warning('提前读到文件末尾 @ frame %d', k);
        break;
    end
    
    % 2) 提取高 12 位
    cfa = bitshift(raw16,-4);
    % 转为 height×width
    cfa = reshape(cfa, [width, height])';
    
    % 3) demosaic
    %    demosaic 要求输入 uint16，输出 uint16
    rgb16 = demosaic(cfa, 'gbrg');
    % 1) 归一化到 [0,1]
    rgbNorm = double(rgb16) / 4095;

    % 2) 设定色彩平衡增益
    gainR = 1.00;    % 红色
    gainG = 0.0;    % 绿色
    gainB = 1.00;    % 蓝色

    % 3) 应用增益
    wbMatrix = reshape([gainR, gainG, gainB], 1,1,3);
    rgbWB = rgbNorm .* wbMatrix;   

    % 4) 裁剪到 [0,1]
    rgbWB = min(max(rgbWB, 0), 1);

    % 5)（可选）回到 8-bit 显示
    rgb8_wb = uint8(rgbWB * 255);

    %{
    figure;
    subplot(1,2,1), imshow(uint8(rgbNorm*255)), title('原始 demosaic');
    subplot(1,2,2), imshow(rgb8_wb),        title('白平衡后');
    %}
    % 4) 缩放到 0–255 / uint8
    %    （4095=max 12-bit；可改为其他归一化方式）
    rgb8 = uint8( double(rgb16) / 4095 * 255 );
    
    % 5) 写入视频
    writeVideo(vw, rgb8_wb);
    
    if mod(k,50)==0
        fprintf('已处理 %d/%d 帧\n', k, numFrames);
    end
end

%% -----------------------------
% 清理收尾
% -----------------------------
fclose(fid);
close(vw);
fprintf('去马赛克视频已写入：%s\n', outputVideo);


%% =============================
% 【可选】如果你想保持 12-bit 精度输出到 H.264 10-bit/12-bit
% 可将上面 writeVideo 的部分替换成：先写 raw，再用 FFmpeg 转码。
% 这里只示例最简写 raw 流步骤——把 rgb16 拼接到一条大的 raw 视频流：
% =============================
% 
% 创建输出 raw 文件
%outRawColor = 'demosaic_rgb16le.bin';
%fidRawC = fopen(outRawColor, 'wb', 'ieee-le');
%{
fseek(fid, 0, 'bof');
for k = 1 : numFrames
   raw16 = fread(fid, width*height, 'uint16=>uint16');
   rgb16 = demosaic(cfa, 'grbg');
   % 按 RGB 三通道写入：uint16 little-endian
   fwrite(fidRawC, permute(rgb16, [2,1,3]), 'uint16');
end
%fclose(fidRawC);
% 
% % 2) 外部调用 FFmpeg（假设颜色格式 rgb48le）：
%cmd = sprintf(['ffmpeg -y -f rawvideo -pixel_format rgb48le -video_size 1936x1088 -framerate 30 -i demosaic_rgb16le.bin -c:v libx265 -pix_fmt yuv420p10le demosaic_10bit.mp4'], width, height, fps, inFile, 'test.mkv');
% 
% % 这样就能得到 10-bit H.265 彩色视频，保留全部 12-bit 亮度细节。
%}