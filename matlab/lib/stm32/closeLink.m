function closeLink(s)
% closeLink  Release the STM32 serial port.
%
%   closeLink(s)
%
%   Flushes and deletes the serialport object, which releases the COM port. Safe to
%   call with an empty or invalid handle.

    if nargin > 0 && ~isempty(s) && isvalid(s)
        try
            flush(s);
        catch
        end
        delete(s);
    end
end
