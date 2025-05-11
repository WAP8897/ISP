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

    % rgbNorm：归一化线性 RGB，double [0,1]
    R = rgbNorm(:,:,1);  G = rgbNorm(:,:,2);  B = rgbNorm(:,:,3);
    
    muR = mean(R, 'all');
    muG = mean(G, 'all');
    muB = mean(B, 'all');
    muMax = max([muR, muG, muB]);
    
    gR = muMax / muR;
    gG = muMax / muG;
    gB = muMax / muB;
    
    wbGain = reshape([gR, gG, gB], 1,1,3);
    rgbWB = rgbNorm .* wbGain;
    rgbWB = min(max(rgbWB,0),1);  % 裁剪到 [0,1]
    
    
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


