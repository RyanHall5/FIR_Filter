function writeHex(filename, v, nbits)
% WRITE_HEX  Write integers as two's-complement hex, one value per line,
% ready for Verilog $readmemh.
    v = v(:);
    assert(all(v == round(v)), 'writeHex: values must be integers');
    nd = ceil(nbits / 4);                    % hex digits per word
    u  = mod(v, 2^nbits);                    % two's complement
    fid = fopen(filename, 'w');
    assert(fid > 0, 'writeHex: cannot open %s', filename);
    fprintf(fid, ['%0' num2str(nd) 'X\n'], u);
    fclose(fid);
end
