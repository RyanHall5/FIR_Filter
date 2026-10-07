function s = openLink(cfg)
% openLink  Open the STM32 serial port with the settings from config().
%
%   s = openLink(cfg)
%
%   Opens serialport(cfg.comPort, cfg.baudRate), sets a 5 s timeout and flushes
%   both buffers. Use closeLink(s) to release the port.

    s = serialport(cfg.comPort, cfg.baudRate);
    s.Timeout = 5;
    flush(s);
end
