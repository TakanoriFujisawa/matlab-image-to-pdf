function image_to_pdf(img, filename)
% 画像配列を PDF ファイル filename に変換する

debug = true;

% 入力引数のチェック
if debug
    narginchk(0, 2);
    if nargin < 2
        img = 'cameraman.tif';
        %img = 'board.tif';
        filename = 'output.pdf';
    end
else
    narginchk(2, 2);
end

validateattributes(filename, {'char'}, {'row'}, mfilename, 'filename', 2);

% 画像を uint8 型に変換
if ischar(img)
    img = imread(img);
else
    img = im2uint8(img);
end

% カラー/グレーの判定
if size(img, 3) > 1
    img_rgb = im2uint8(img);
    img_gray = im2uint8(rgb2gray(img));
    is_color = ~ all((img_rgb(:) - repmat(img_gray(:), 3, 1)) == 0);
else
    img_gray = im2uint8(img);
    is_color = false;
end

% ファイル名に .pdf がないときには自動的に拡張子を追加
[dir, name, ext] = fileparts(filename);
if ~ strcmpi(ext, '.pdf')
    name = [name, ext];
    ext = '.pdf';
end

% 書き出し処理
if is_color
    do_write_pdf(img_rgb, dir, name, ext);
else
    do_write_pdf(img_gray, dir, name, ext);
end

end

%%
function do_write_pdf(img_data, dir, name, ext)

data.NAME = name;
data.DATE = char(datetime('now', 'Format', 'yMMddHHmmss'));
data.WIDTH = num2str(size(img_data, 2));
data.HEIGHT = num2str(size(img_data, 1));
data.LENSTREAM5 = num2str(length(['q  0 0  0 0 cm /Im0 Do Q' data.WIDTH data.HEIGHT]));

% 画像データの並び替え
if size(img_data, 3) > 1
    data.IMAGETYPE = '/ImageC';
    data.COLORSPACE = '/DeviceRGB';
    img_data = reshape(permute(img_data, [3, 2, 1]), 1, []);
else
    data.IMAGETYPE = '/ImageI';
    data.COLORSPACE = '/DeviceGray';
    img_data = reshape(transpose(img_data), 1, []);
end

% 画像データの圧縮
[img_data, is_compressed] = do_compress(img_data);
img_data = char(img_data);

if is_compressed
    data.FILTER = '/Filter [ /FlateDecode ]';
else
    data.FILTER = '';
end

data.LENSTREAM6 = num2str(numel(img_data));

objects = {
    % 1
    [ '1 0 obj' nl ...
        '<< /Pages 3 0 R /Type /Catalog >>' nl ...
        'endobj' nl nl ]
    % 2
    [ '2 0 obj' nl ...
        '<< /CreationDate (' data.DATE ') /ModDate (' data.DATE ')' ...
        ' /Producer (MATLAB ImageToPDF) /Title (' data.NAME ') >>' nl ...
        'endobj' nl nl ]
    % 3
    [ '3 0 obj' nl ...
        '<< /Count 1 /Kids [ 4 0 R ] /Type /Pages >>' nl ...
        'endobj' nl nl ]
    % 4
    [ '4 0 obj' nl ...
        '<< /Contents 5 0 R /CropBox [ 0 0 ' data.WIDTH ' ' data.HEIGHT ' ]' ...
        ' /MediaBox [ 0 0 ' data.WIDTH ' ' data.HEIGHT ' ] /Parent 3 0 R ' ...
        ' /Resources << /ProcSet [ /PDF /Text ' data.IMAGETYPE ' ]' ...
        ' /XObject << /Im0 6 0 R >> >> /Type /Page >>' nl ...
        'endobj' nl nl ]
    % 5
    [ '5 0 obj' nl ...
        '<< /Length ' data.LENSTREAM5 ' >>' nl ...
        'stream' nl ... 
        'q' nl ...
        data.WIDTH ' 0 0 ' data.HEIGHT ' 0 0 cm /Im0 Do' nl ...
        'Q' nl ...
        'endstream' nl ...
        'endobj' nl nl ]
    % 6
    [ '6 0 obj' nl ...
        '<< /BitsPerComponent 8 /ColorSpace ' data.COLORSPACE ...
        ' /Height ' data.HEIGHT ' /Name /Im0' ...
        ' /Subtype /Image /Type /XObject /Width ' data.WIDTH ...
        ' /Length ' data.LENSTREAM6 ' ' data.FILTER ' >>' nl ...
        'stream' nl ...
        char(img_data) nl ...
        'endstream' nl ...
        'endobj' nl nl ]
};

pdf_header = ['%PDF-1.3', char(uint8([10, 37, 191, 247, 162, 10, 10]))];
offsets = cumsum([numel(pdf_header); cellfun(@numel, objects)]);

pdf_xref = cell(length(objects) + 2, 1);
pdf_xref{1} = sprintf('xref\n0 %d\n0000000000 65535 f \n', length(objects) + 1);
for i = 1 : length(objects)
    pdf_xref{1 + i} = sprintf('%010d 00000 n \n', offsets(i));
end
pdf_xref{end} = sprintf('trailer\n<<\n  /Info 2 0 R /Root 1 0 R /Size %d\n>>\n', ...
    length(objects) + 1);

pdf_footer = sprintf('startxref\n%d\n%%%%EOF\n\n', offsets(end));

% ファイルへの書き出し
fid = fopen(fullfile(dir, [name, ext]), 'w');
obj = onCleanup(@()fclose(fid));
write = @(bytes)fwrite(fid, uint8(bytes));

write(pdf_header);
cellfun(write, objects);
cellfun(write, pdf_xref);
write(pdf_footer);

end

%%
function c = nl()
% newline
c = char(10);
end

%%
function [ output, is_compressed ] = do_compress(data)

if nargin == 0
    data = uint8(randi(255, 1, 20));
end

validateattributes(data, {'uint8'}, {'vector'});

try
    % Python 2 / 3 どちらでも同じになるはず
    output = uint8(py.zlib.compress(data, py.int(9)));
    is_compressed = true;
catch
    output = data;
    is_compressed = false;
end

end

%%
