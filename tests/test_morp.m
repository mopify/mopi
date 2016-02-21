% Tests for morp.m and morp.sh, implemented
% with the MOxUnit framework.
function test_suite = test_morp()
    % Setup fixtures
    setup();
    % Top level function should call initTestSuite and return the
    % variable test_suite (which initTestSuite will put into the
    % workspace for us).
    initTestSuite;
    % Tear-down fixtures
    tear_down();
end

% ---------------------------------------------------------------------
% Setup fixtures
function setup()
    fid = fopen('requirements_testing.txt', 'w');
    fprintf(fid, '# Packages for testing installation\n');
    %fprintf(fid, 'forge://control\n');
    fprintf(fid, 'fex://55540-dummy-package\n');
    fprintf(fid, 'fex://31069-require-fex-package\n');
    fprintf(fid, 'http://www.colorado.edu/conflict/peace/download/peace_essay.ZIP\n');
    fclose(fid);
end

% Tear-down fixtures
function tear_down()
    delete('requirements_testing.txt');
end

% ---------------------------------------------------------------------
% Check whether we are inside a continuous integration testing environment
function tf = is_continuous_integration()
    [~, res] = system('echo $CI');
    if isempty(strtrim(res))
        tf = false;
    else
        tf = true;
    end
end

%isoctave  Determine if the environment is Octave
%   isoctave() true if the operating environment is Octave, otherwise
%   it returns false, indicating the environment is something else
%   (MATLAB, Scilab, FreeMat, etc).
function tf = isoctave()
    tf = exist('OCTAVE_VERSION', 'builtin') ~= 0;
end

% ---------------------------------------------------------------------
function check_full(method)
    PKG_DIR = 'external_test';
    CACHE_DIR = '.cache';
    FNAME = 'requirements_testing.txt';
    OCTAVGE_PKG = 'control';
    PKG_LIST = {
        ['forge://' OCTAVGE_PKG];
        'fex://55540-dummy-package';
        'http://www.colorado.edu/conflict/peace/download/peace_essay.ZIP';
    };
    EXPECTED_FILES = {
        fullfile(PKG_DIR, '55540', 'dummy.txt');
        fullfile(PKG_DIR, 'peace_essay', 'civility.htm');
    };
    % Delete old fixtures
    if exist(PKG_DIR, 'dir'); rmdir(PKG_DIR, 's'); end
    if exist(CACHE_DIR, 'dir'); rmdir(CACHE_DIR, 's'); end
    if isoctave() && is_continuous_integration() ...
            && ~isempty(pkg('list', OCTAVGE_PKG))
        fprintf('Removing existing copy of %s\n', OCTAVGE_PKG);
        pkg('uninstall', OCTAVGE_PKG);
    end
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./morp.sh %s %s -', FNAME, PKG_DIR));
            assertTrue(status==0);
        case 'matlab'
            % Run the matlab script with a file input
            morp(FNAME, PKG_DIR, false, CACHE_DIR);
        case 'matlab-cell'
            % Run the matlab script with a cell input
            morp(PKG_LIST, PKG_DIR, false, CACHE_DIR);
        otherwise
            error('Bad argument');
    end
    % Assert files exist
    assertTrue(exist(EXPECTED_FILES{1}, 'file'));
    assertTrue(exist(EXPECTED_FILES{2}, 'file'));
    for iFile=3:numel(EXPECTED_FILES)
        assertTrue(exist(EXPECTED_FILES{iFile}, 'file'));
    end
    if isoctave()
        assertFalse(~isempty(pkg('list', OCTAVGE_PKG)));
    end
end

function test_shellscript_full()  %#ok<*DEFNU>
    check_full('shell');
end

function test_mscript_file()
    check_full('matlab');
end

function test_mscript_cell()
    check_full('matlab-cell');
end

% ---------------------------------------------------------------------
% Test Forge package can be installed, by shell or matlab script
function check_forge(method, includeProtocol)
    % Declare constants
    PKG_NAME = 'control';
    FNAME = 'requirements_testforge.txt';
    PKG_DIR = 'external_test';
    % Can only test Forge installation on Octave
    if ~isoctave()
        moxunit_throw_test_skipped_exception( ...
            'Can only test Forge installation on Octave');
    end
    if is_continuous_integration()
        % Remove existing copy of package
        if ~isempty(pkg('list', PKG_NAME))
            fprintf('Removing existing copy of %s\n', PKG_NAME);
            pkg('uninstall', PKG_NAME);
        end
    end
    % Make a file to use for testing
    fid = fopen(FNAME, 'w');
    fprintf(fid, '# Octave Forge unit test requirements file\n');
    if includeProtocol
        fprintf(fid, 'forge://');
    end
    fprintf(fid, [PKG_NAME '\n']);
    fclose(fid);
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./morp.sh %s %s -', FNAME, PKG_DIR));
            assertTrue(status==0);
        case 'matlab'
            % Run the matlab script
            morp(FNAME, PKG_DIR, false);
        otherwise
            error('Bad argument');
    end
    % Make sure packages were installed
    assertFalse(~isempty(pkg('list', PKG_NAME)));
    % Delete testing file
    delete(FNAME);
end

function test_shellscript_forge()
    check_forge('shell', true);
end

function test_shellscript_forge_without_protocol()
    check_forge('shell', false);
end

function test_mscript_forge()
    check_forge('matlab', true);
end

function test_mscript_forge_without_protocol()
    check_forge('matlab', false);
end

% ---------------------------------------------------------------------
% Test package can be installed from generic URI, by shell or matlab script
function check_url(method)
    % Declare constants
    URI = 'http://www.colorado.edu/conflict/peace/download/peace_essay.ZIP';
    PKG_DIR = 'external_test';
    CACHE_DIR = '.cache';
    FNAME = 'requirements_testurl.txt';
    EXPECTED_FILE = fullfile(PKG_DIR, 'peace_essay', 'civility.htm');
    % Setup fixtures
    % Delete old fixtures
    if exist(PKG_DIR, 'dir'); rmdir(PKG_DIR, 's'); end
    if exist(CACHE_DIR, 'dir'); rmdir(CACHE_DIR, 's'); end
    if exist(FNAME, 'file'); delete(FNAME); end
    % Make a file to use for testing
    fid = fopen(FNAME, 'w');
    fprintf(fid, '# URI package installation unit test requirements file\n');
    fprintf(fid, [URI '\n']);
    fclose(fid);
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./morp.sh %s %s -', FNAME, PKG_DIR));
            assertTrue(status==0);
        case 'matlab'
            % Run the matlab script
            morp(FNAME, PKG_DIR, false, CACHE_DIR);
        otherwise
            error('Bad argument');
    end
    % Make sure packages were installed
    assertTrue(exist(EXPECTED_FILE, 'file'));
    % Delete testing file
    delete(FNAME);
    rmdir(fileparts(EXPECTED_FILE), 's');
end

function test_shellscript_url()
    check_url('shell');
end

function test_mscript_url()
    check_url('matlab');
end

% ---------------------------------------------------------------------
% Test FEX package can be installed, by shell or matlab script
function check_fex(method, includeProtocol)
    % Declare constants
    PKG_NAME = '55540-dummy-package';
    PKG_DIR = 'external_test';
    CACHE_DIR = '.cache';
    FNAME = 'requirements_testfex.txt';
    EXPECTED_FILE = fullfile(PKG_DIR, '55540', 'dummy.txt');
    % Setup fixtures
    % Delete old fixtures
    if exist(PKG_DIR, 'dir'); rmdir(PKG_DIR, 's'); end
    if exist(CACHE_DIR, 'dir'); rmdir(CACHE_DIR, 's'); end
    if exist(FNAME, 'file'); delete(FNAME); end
    % Make a file to use for testing
    fid = fopen(FNAME, 'w');
    fprintf(fid, '# FileExchange unit test requirements file\n');
    if includeProtocol
        fprintf(fid, 'fex://');
    end
    fprintf(fid, [PKG_NAME '\n']);
    fclose(fid);
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./morp.sh %s %s -', FNAME, PKG_DIR));
            assertTrue(status==0);
        case 'matlab'
            % Run the matlab script
            morp(FNAME, PKG_DIR, false, '.cache');
            rmdir('.cache', 's');
        case 'matlab-int-id'
            % Run the matlab script on an integer input
            morp(55540, PKG_DIR, false, '.cache');
            rmdir('.cache', 's');
        case 'matlab-addpath'
            % Run the matlab script, and add path
            morp(FNAME, PKG_DIR, true, '.cache');
            rmdir('.cache', 's');
            assertFalse(isempty(which(EXPECTED_FILE)));
            % Remove path
            rmpath(fileparts(EXPECTED_FILE));
        otherwise
            error('Bad argument');
    end
    % Make sure packages were installed
    assertTrue(exist(EXPECTED_FILE, 'file'));
    % Delete testing file
    delete(FNAME);
    rmdir(fileparts(EXPECTED_FILE), 's');
end

function test_shellscript_fex()
    check_fex('shell', true);
end

function test_shellscript_fex_without_protocol()
    check_fex('shell', false);
end

function test_mscript_fex()
    check_fex('matlab', true);
end

function test_mscript_fex_without_protocol()
    check_fex('matlab', false);
end

function test_mscript_fex_int_id()
    check_fex('matlab-int-id', true);
end

function test_mscript_fex_addpath()
    check_fex('matlab-addpath', true);
end