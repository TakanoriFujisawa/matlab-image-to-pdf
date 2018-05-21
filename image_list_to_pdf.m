function image_list_to_pdf(varargin)
% 画像配列を PDF ファイル filename に変換する

% image_list_to_pdf(imglist, filename, namelist, pdfinfo)
% 
% imglist  : 画像のセル配列
% filename  : PDF ファイル名
% namelist : [optional] ブックマークにする文字列のセル配列
% pdfinfo   : [optional] 構造体
%     name PDF メタデータの名前

debug = true;
[imglist, filename, namelist, pdfinfo] = parse_inputs(debug, varargin{:});

num_pages = length(imglist);

% 置き換える文字列
DATE = char(datetime('now', 'Format', 'yMMddHHmmss'));
PRODUCER = pdfstring(pdfinfo.producer);
NAME = pdfstring(pdfinfo.name);
NUMPAGES = num2str(num_pages);
% 5, 9, 13 ...
KIDS = sprintf(' %d 0 R ', 1 + 4 * (1 : num_pages));
% 8
FIRST = '8 0 R';
LAST = sprintf('%d 0 R', 4 + 4 * num_pages);

objects = cell(4 + 4 * num_pages, 1);
objects(1 : 4) = {
    '<< /Pages 3 0 R /Type /Catalog /Outlines 4 0 R /PageMode /UseOutlines >>'
    ['<< /CreationDate (' DATE ') /ModDate (' DATE ')' ...
        ' /Producer ' PRODUCER ' /Title ' NAME ' >>']
    ['<< /Count ' NUMPAGES ' /Kids [ ' KIDS ' ] /Type /Pages >>']
    ['<< /Count ' NUMPAGES ' /First ' FIRST ' /Last ' LAST ' >>']
};

for p = 1 : num_pages
    objects(4 * p + 1 : 4 * p + 4) = page_entry(imglist{p}, num_pages, p, namelist{p});
end

for n = 1 : length(objects)
    objects{n} = [ sprintf('%d 0 obj\n', n), objects{n}, sprintf('\nendobj\n\n') ];
end

for n = 1 : length(objects)
    disp(objects{n}(1:min(end,200)))
end

%% ヘッダー
pdf_header = ['%PDF-1.4', char(uint8([10, 37, 191, 247, 162, 10, 10]))];

%% オフセットの計算
offsets = cumsum([numel(pdf_header); cellfun(@numel, objects)]);

%% XRef テーブルの作成
pdf_xref = cell(length(objects) + 2, 1);
pdf_xref{1} = sprintf('xref\n0 %d\n0000000000 65535 f \n', length(objects) + 1);
for n = 1 : length(objects)
    pdf_xref{1 + n} = sprintf('%010d 00000 n \n', offsets(n));
end

%% Trailer, フッターの作成
pdf_xref{end} = sprintf('trailer\n<<\n  /Info 2 0 R /Root 1 0 R /Size %d\n>>\n', ...
    length(objects) + 1);

pdf_footer = sprintf('startxref\n%d\n%%%%EOF\n\n', offsets(end));

%% PDF に書き出し
fid = fopen(filename, 'w');
fwrite(fid, uint8(pdf_header));
for n = 1 : length(objects)
    fwrite(fid, uint8(objects{n}));
end
for n = 1 : length(pdf_xref)
    fwrite(fid, uint8(pdf_xref{n}));
end
fwrite(fid, uint8(pdf_footer));
fclose(fid);

end

%%
function objs = page_entry(img, num_pages, p, name)

PAGE_PARENT = '3 0 R';
OUTLINE_PARENT = '4 0 R';
DEST_PAGE = sprintf('%d 0 R', 1 + 4 * p);

if p == 1
    PREV = '';
    if num_pages == 1
        NEXT = '';
    else
        NEXT = sprintf('/Next %d 0 R', 4 + 4 * (p + 1));
    end
elseif p == num_pages
    PREV = sprintf('/Prev %d 0 R', 4 + 4 * (p - 1));
    NEXT = '';
else
    PREV = sprintf('/Prev %d 0 R', 4 + 4 * (p - 1));
    NEXT = sprintf('/Next %d 0 R', 4 + 4 * (p + 1));
end

WIDTH = num2str(size(img, 2));
HEIGHT = num2str(size(img, 1));

% 画像データの並び替え
if size(img, 3) > 1
    IMAGETYPE = '/ImageC';
    COLORSPACE = '/DeviceRGB';
    img = reshape(permute(img, [3, 2, 1]), 1, []);
else
    IMAGETYPE = '/ImageI';
    COLORSPACE = '/DeviceGray';
    img = reshape(transpose(img), 1, []);
end

try
    IMAGE = char(uint8(py.zlib.compress(img)));
    FILTER = '/Filter [ /FlateDecode ]';
catch
    IMAGE = char(img);
    FILTER = '';
end

CONTENTS = sprintf('%d 0 R', 2 + 4 * p);
IM0 = sprintf('/Im%d', p - 1);
%IM0 = '/Im0';
XOBJECT = sprintf('<< %s %d 0 R >>', IM0, 3 + 4 * p);
LENSTREAM1 = num2str(length(['q  0 0  0 0 cm  Do Q' IM0 WIDTH HEIGHT]));
LENSTREAM2 = num2str(numel(IMAGE));

NAME = pdfstring(name);

nl = char(10);

objs = {
    ['<< /Contents ' CONTENTS ' /CropBox [ 0 0 ' WIDTH ' ' HEIGHT ' ]' ...
        ' /MediaBox [ 0 0 ' WIDTH ' ' HEIGHT ' ] /Parent ' PAGE_PARENT ' ' ...
        ' /Resources << /ProcSet [ /PDF /Text ' IMAGETYPE ' ] ' ...
        ' /XObject ' XOBJECT ' >> /Type /Page >>']
    ['<< /Length ' LENSTREAM1 ' >>' nl ...
        'stream' nl ...
        'q' nl ...
        WIDTH ' 0 0 ' HEIGHT ' 0 0 cm ' IM0 ' Do' nl ...
        'Q' nl ...
        'endstream' ]
    ['<< /BitsPerComponent 8 /ColorSpace ' COLORSPACE ...
        ' /Height ' HEIGHT ' /Name ' IM0 ' /Subtype /Image /Type /XObject' ...
        ' /Width ' WIDTH ' /Length ' LENSTREAM2 ' ' FILTER ' >>' nl ...
        'stream' nl ...
        IMAGE nl ...
        'endstream' ]
    ['<< /Title ' NAME ' ' ...
        '/Dest [ ' DEST_PAGE ' /XYZ 0 ' HEIGHT ' null ] ' ...
        '/Parent ' OUTLINE_PARENT ' ' NEXT ' ' PREV ' >>']
};

end

%%
function code = pdfstring(str)

if ~ all(isstrprop(str, 'print'))
    error('無効な PDF 文字列: %s', str);
end

if all(str < 256)
    str = strrep(strrep(str, '(', '\('), ')', '\)');
    code = [ '(', str, ')' ];
else
    try
        code = [ '<feff' ...
            sprintf('%02x', uint8(py.unicode(str).encode('utf-16-be'))) '>' ];
    catch
        error('非アスキー文字列をエンコードできません');
    end
end

end

%%
function [imglist, filename, namelist, pdfinfo] = parse_inputs(varargin)

debug = varargin{1};

if debug
    narginchk(1, 5);
else
    narginchk(3, 5);
end

% 第 1 引数
if nargin < 2
    imglist = { imread('cameraman.tif'), imread('board.tif'), rand(5, 4, 3) };
else
    imglist = varargin{2};
end

imglist = cellfun(@(n)im2uint8(n), imglist, 'UniformOutput', false);

% 第 2 引数
if nargin < 3
    filename = 'output.pdf';
else
    filename = varargin{3};
    validateattributes(filename, {'char'}, {'row'}, mfilename, 'filename', 2);
end

[dir, name, ext] = fileparts(filename);

if ~ strcmp(ext, '.pdf')
    name = [name, ext];
    ext = '.pdf';
end

filename = fullfile(dir, [name, ext]);

% 第 3 引数
if nargin < 4
    namelist = arrayfun(@(n)sprintf('画像%d', n), 1 : length(imglist), 'UniformOutput', false);
else
    namelist = varargin{4};
    validateattributes(namelist, {'cell'}, ...
        {'vector', 'numel', numel(imglist)}, mfilename, 'namelist', 3);
    for i = 1 : length(namelist)
        validateattributes(namelist{i}, {'char'}, {'row'}, mfilename, 'namelist', 3);
    end
end

% 第 4 引数
if nargin < 5
    pdfinfo = struct;
else
    pdfinfo = varargin{5};
    validateattributes(pdfinfo, {'struct'}, {'scalar'}, mfilename, 'namelist', 5);
end

if ~ isfield(pdfinfo, 'name')
    pdfinfo.name = '画像';
end

if ~ isfield(pdfinfo, 'producer')
    pdfinfo.producer = 'MATLAB ImageToPDF';
end

end

%%