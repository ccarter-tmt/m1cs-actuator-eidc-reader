% M1CS_Read_Actuator_EIDC.m
%
% Author: Chris Carter
% Email: ccarter@tmt.org
% Revision Date: 8th September 2022
% Version: 1.0
%
% VERSION NOTES:
%
% V1.0 - Reads OneWire device Family, Unique ID and CRC. Does not attempt
% to verify the received CRC.
%
% INSTALLATION NOTES:
%
% This script requires the LabJack LJM Library which, amongst other things,
% enables communication between MATLAB and the LabJack T4 data acquisition
% unit.
%
% The LabJack LJM Library is introduced here: https://labjack.com/ljm
% The MATLAB LJM Library is available here: https://labjack.com/support/software/examples/ljm/matlab
%
% The MATLAB LJM Library should be unpacked and stored in a location on the
% machine running the script, and added to the MATLAB PATH.
%
% Script has been shown to work with a LabJack T4 and MATLAB Version
% 9.13.0.1967605 (R2022b) Prerelease.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set up the MATLAB environment

clc         % Clear the command window
clear all   % Clear previous environment variables and functions

% Some variable definitions

OWF_Search = 0xF0;
nbytes = 8;

% Make the LJM .NET assembly visible

ljmAsm = NET.addAssembly('LabJack.LJM');

% Create an object to nested class LabJack.LJM.CONSTANTS

t = ljmAsm.AssemblyHandle.GetType('LabJack.LJM+CONSTANTS');
LJM_CONSTANTS = System.Activator.CreateInstance(t);

handle = 0;

try
    % Open any available LabJack device, using any connection, with any
    % identifier

    [ljmError, handle] = LabJack.LJM.OpenS('ANY', 'ANY', 'ANY', handle);
    showDeviceInfo(handle);

    % Talk to any OneWire device found. See the following for details of
    % LabJack support for OneWire on the T-series hardware:
    %
    % https://labjack.com/support/datasheets/t-series/digital-io/1-wire

    % Set the OneWire data-line to use EIO0 (DB connector pin 4, DIO8) on
    % the LabJack T4
    
    fprintf("\n - Setting up EIO8 for OneWire use...");

    [ljmError] = LabJack.LJM.eWriteName(handle, 'ONEWIRE_DQ_DIONUM', 8);

    fprintf(" done\n")

    % Disable the 'Dynamic Pull Up' capability of the LabJack T4

    fprintf(" - Disabling DPU capability...");

    [ljmError] = LabJack.LJM.eWriteName(handle, 'ONEWIRE_DPU_DIONUM', 0);
    [ljmError] = LabJack.LJM.eWriteName(handle, 'ONEWIRE_OPTIONS', 0);

    fprintf(" done\n")

    % Set up OneWire data transfer

    fprintf(" - Configure to receive %i bytes over OneWire...", nbytes)

    [ljmError] = LabJack.LJM.eWriteName(handle, 'ONEWIRE_NUM_BYTES_RX',...
        nbytes);

    fprintf(" done\n")

    % Read the ROM on the OneWire device

    fprintf(" - Read the DS2401 ROM...")

    [ljmError] = LabJack.LJM.eWriteName(handle, 'ONEWIRE_FUNCTION',...
        OWF_Search);
    [ljmError] = LabJack.LJM.eWriteName(handle, 'ONEWIRE_GO', 1);

    fprintf(" done\n")

    % Read bytes returned over OneWire

    result_H = uint32(0);
    result_L = uint32(0);

    [ljmError, result_H] = LabJack.LJM.eReadName(handle, 'ONEWIRE_SEARCH_RESULT_H',...
        0);
    [ljmError, result_L] = LabJack.LJM.eReadName(handle, 'ONEWIRE_SEARCH_RESULT_L',...
        0);

    % Parse the returned values and report to user

    result_HL = bitshift(uint64(result_H),32);
    result_HL = bitor(result_HL, uint64(result_L));
    
    bindata = dec2bin(result_HL,64);
    
    family = 0x0u8;      % Least significant byte 1
    id = 0x0u64;         % Bytes 2-7
    crc = 0x0u8;         % Most significant byte 8
    
    family = uint8(bitand(result_L,0xFFu32));
    crc = uint8(bitshift(bitand(result_H, 0xFF000000), -24));
    
    idu = uint64(bitand(result_H, 0x00FFFFFF));
    idu = bitshift(idu,24);
    idl = bitand(result_L, 0xFFFFFF00);
    idl = bitshift(idl, -8);
    
    idu = uint64(idu);
    idl = uint64(idl);
    
    id = bitor(idu, idl);
    
    fprintf('\nCaptured DS2401 OneWire device information retrieved:\n')
    fprintf("\n - Device family: 0x%Xh\n", family)
    fprintf(" - Device Unique ID: 0x%Xh\n", id)
    fprintf(" - Device CRC: 0x%Xh\n", crc)
    fprintf('\n');

catch e
    showErrorMessage(e)
    LabJack.LJM.CloseAll();
    return
end

try
    % Close handle to LabJack device

    LabJack.LJM.Close(handle);

catch e
    showErrorMessage(e)
end

% End of file