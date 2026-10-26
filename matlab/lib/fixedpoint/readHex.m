function v = readHex(filename, nbits)
% readHex  Read a two's-complement hex file written by writeHex back into integers.
%
%   v = readHex(filename, nbits)
%
%     filename  hex file, one value per line (as written by writeHex / read by $readmemh)
%     nbits     word width in bits
%     v         column vector of signed integers (doubles)
%
%   Used by the hardware vector test (stage 06) and analysis (stage 07) to load the
%   test inputs and expected outputs in data/vectors/.
%
%   AI note: written by Claude (Anthropic) at the author's request.

    fid = fopen(filename, 'r');
    if fid < 0
        error('readHex:openFailed', 'Cannot open %s.', filename);
    end
    cleanup = onCleanup(@() fclose(fid));

    c = textscan(fid, '%s');
    if isempty(c{1})
        v = zeros(0, 1);
        return;
    end

    u = hex2dec(c{1});                 % unsigned value of each line
    v = u;
    neg = u >= 2^(nbits - 1);          % sign bit set: undo two's complement
    v(neg) = u(neg) - 2^nbits;
end
