% ブックマーク付き PDF

% ・オブジェクト /Catalog にプロパティ /Outlines をつける
%   /PageMode もつけておくと良い
%  --------------------------------------------------
%   1 0 obj
%   << /Outlines 6 0 R /PageMode /UseOutlines /Pages 7 0 R /Type /Catalog >>
%   endobj
%  --------------------------------------------------

% ・/Outlines のオブジェクト，プロパティは /Count /First /Last
%   /First，/Last はブックマークのオブジェクト
%   ブックマークが 1 つだけの時は /First と /Last の指すものが同じに
%  --------------------------------------------------
%   6 0 obj
%   << /Count 3 /First 11 0 R /Last 12 0 R >>
%   endobj
%  --------------------------------------------------

% ・ブックマークのオブジェクト，/Parent /Prev /Next を持つ木構造？
%   座標を /Dest で，ブックマークを /Title で記載
%   例の 5 0 R は /Page のオブジェクト
%   座標は左下が原点っぽい
%  --------------------------------------------------
%    14 0 obj
%    <<
%      /Dest [ 5 0 R /XYZ 124.802 706.129 null ]
%      /Next 12 0 R  /Parent 6 0 R  /Prev 11 0 R
%      /Title (Somename 2)
%    >>
%    endobj
%  --------------------------------------------------


% 1ページ画像1枚，各ページにブックマークの PDF ファイルの場合こうなる？
%
% Catalog
%   +-(Pages)-> Pages
%   |             +-(Kids)-+-> Page
%   |                      |
%   |                      +-> Page
%   |                            +-(Contents)-> stream
%   |                            +-(XObjects)-> XObject/Image
%   |
%   +-(Outlines)-> Outlines
%                    +-(First)-> Outline
%                    |               +-(Next)--v
%                    |                        Outline
%                    |               v--(Next)-+
%                    +-(Last)--> Outline
%
% Info

% 手順
% Catalog オブジェクトを作成
% Info オブジェクトを作成
% Pages オブジェクトを作成 (Kids は未定)
% Outlines オブジェクトを作成 (Count, First, Last は未定)
% for 各画像について
%     Page, Contents, Image, Outline のオブジェクトを作成
%     Outline の Prev, Next は未定


% 各ページに必要なオブジェクト数がわかっているので後から置換しなくてもできそう
% 番号の振り当て
%   magic
%   1. Catalog
%   2. Info
%   3. Pages
%   4. Outlines
%   5+4n. Page
%   6+4n. Contents
%   7+4n. XObject/Image
%   8+4n. Outline
%   5+4N. xref
%   trailer
%   startxref
%
% xref 直前までのオブジェクトの数 = 4 + 4 * N
