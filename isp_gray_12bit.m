% -----------------------------
% 参数设置
% -----------------------------
inFile       = 'day.bin';        % 输入 RAW bin
outRawFile   = 'processed.bin';    % 处理后临时 RAW
width        = 1936;
height       = 1088;
bytesPerPix  = 2;                  % uint16 存储
fps          = 30;
depthOption  = '10bit';            % '12bit' 或 '10bit'
machineFormat= 'ieee-be';          % 根据实际文件选择 'ieee-le' 或 'ieee-be'

% -----------------------------
% 打开文件
% -----------------------------
fidIn  = fopen(inFile,  'rb', machineFormat);
fidOut = fopen(outRawFile,'wb',machineFormat);
if fidIn<0 || fidOut<0
    error('打开文件失败，请检查路径和大小端设置');
end

% 计算帧数
fseek(fidIn,0,'eof');
numFrames = floor(ftell(fidIn)/(width*height*bytesPerPix));
fseek(fidIn,0,'bof');
fprintf('预计处理帧数：%d\n', numFrames);

% -----------------------------
% 按帧处理并写出 RAW
% -----------------------------
for k = 1:numFrames
    raw16 = fread(fidIn, width*height, 'uint16=>uint16');
    if numel(raw16)<width*height, break; end
    
    % 还原 12-bit
    frame12 = bitshift(raw16,-4);
    frame16 = frame12*16;
    frame12 = reshape(frame12, [width, height])'; % 转为 height×width
    frame16 = reshape(frame16, [width, height])';
    raw16 = reshape(raw16, [width, height])';

    
    % 选项：降到 10-bit 或保留 12-bit
    switch depthOption
      case '12bit'
        outFrame = uint16(frame16);
      case '10bit'
        outFrame = uint16(bitshift(frame12,-2));   % 12→10bit
      otherwise
        error('depthOption 只能是 “12bit” 或 “10bit”');
    end
    
    % 写入 processed.bin
    fwrite(fidOut, outFrame', 'uint16');  % 注意转列优先
    
end

fclose(fidIn);
fclose(fidOut);
fprintf('RAW 流已写入 %s\n', outRawFile);

% -----------------------------
% 调用 FFmpeg 进行编码
% -----------------------------
% 1) 无损 FFV1，保留全 16-bit（其中只有 high bits 有效）
% 2) 保存为 output.mkv（也可改 .avi）
cmd = sprintf([ ...
  'ffmpeg -y ' ...                                 % 覆盖同名输出
  '-f rawvideo ' ...                               % 原始视频流
  '-pixel_format gray16be ' ...                    % 16-bit BE 灰度
  '-video_size %dx%d ' ...                         % 分辨率
  '-framerate %d ' ...                             % 帧率
  '-i "%s" ' ...                                   % 输入流
  '-c:v ffv1 "%s"'], ...                           % 无损 FFV1 编解码
  width, height, fps, inFile, 'output.mkv');

fprintf('正在调用 FFmpeg 编码，请稍候...\n');
status = system(cmd);
if status~=0
    error('FFmpeg 编码失败，请确认已安装并在 PATH 中\n命令：%s', cmd);
end

fprintf('完成：生成高位深视频 output.mkv（%s）\n', depthOption);
