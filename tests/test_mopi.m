% Tests for mopi.m and mopi.sh, implemented
% with the MOxUnit framework.
function test_suite = test_mopi()
    % Top level function should call initTestSuite and return the
    % variable test_suite (which initTestSuite will put into the
    % workspace for us).
    initTestSuite;
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

%find_exist  Search for a file inside directory and its children
%   Finds only the first matching file, then stops.
function [result, pth] = find_exist(file, directory, skip_dirs, maxdepth, ...
        currentdepth)
    % Input handling --------------------------------------------------
    % Default inputs
    if nargin<3
        skip_dirs = {};
    end
    if nargin<4
        maxdepth = -1;
    end
    if nargin<5
        currentdepth = 0;
    end
    % Declare which directories we don't want to add to the path
    AVOID_DIRNAMES = {'.'; '..'};
    AVOID_DIRNAMES = [AVOID_DIRNAMES(:); skip_dirs(:)];
    % Main ------------------------------------------------------------
    % Initialise output
    pth = '';
    % Check current
    check_name = fullfile(directory, file);
    result = exist(check_name, 'file');
    if result ~= 0
        pth = check_name;
        return;
    end
    if maxdepth >= 0 && currentdepth >= maxdepth
        return;
    end
    % Generate path based on given root directory
    contents = dir(directory);
    if isempty(contents)
        return;
    end
    % Select only directories
    contents = contents(cat(1, contents.isdir));
    % Remove directories we want to avoid
    contents = contents(~ismember({contents.name}, AVOID_DIRNAMES));
    % Descend into contained directories
    for i=1:length(contents)
        % Recursively call this function
        [result, pth] = find_exist(file, ...
            fullfile(directory, contents(i).name), skip_dirs, maxdepth, ...
            currentdepth+1);
        % If we find a match, we can exit
        if result ~= 0;
            return;
        end
    end
end

% ---------------------------------------------------------------------
% Test Forge package can be installed, by shell or matlab script
function check_forge(method, includeProtocol)
    % Declare constants
    PKG_NAME = 'control';
    % Setup fixtures
    PKG_DIR = tempname;
    FNAME = [tempname '.txt'];
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
    % Run command
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./mopi.sh %s %s -', FNAME, PKG_DIR));
            assertEqual(0, status);
        case 'matlab'
            % Run the matlab script
            mopi(FNAME, PKG_DIR, false);
        otherwise
            error('Bad argument');
    end
    % Make sure packages were installed
    assertFalse(isempty(pkg('list', PKG_NAME)));
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
% Test package can be installed from generic URL, by shell or matlab script
function check_url(method, extension, addInlineComment)
    % Declare constants
    switch lower(extension)
        case 'zip'
            URL = 'http://www.mathworks.com/moler/ncm.zip';
        case 'tar.gz'
            URL = 'http://www.mathworks.com/moler/ncm.tar.gz';
        otherwise
            error('Can''t handle %s extension', extension);
    end
    % Setup fixtures
    PKG_DIR = tempname;
    CACHE_DIR = tempname;
    FNAME = [tempname '.txt'];
    EXPECTED_FILE = 'vandal.m';
    EXPECTED_DIR = fullfile(PKG_DIR, 'ncm');
    % Delete old fixtures
    if exist(PKG_DIR, 'dir'); rmdir(PKG_DIR, 's'); end
    if exist(CACHE_DIR, 'dir'); rmdir(CACHE_DIR, 's'); end
    if exist(FNAME, 'file'); delete(FNAME); end
    % Make a file to use for testing
    fid = fopen(FNAME, 'w');
    fprintf(fid, '# URL package installation unit test requirements file\n');
    fprintf(fid, URL);
    if addInlineComment
        fprintf(fid, ' # inline comment: indeed! #truestory');
    end
    fprintf(fid, '\n');
    fclose(fid);
    % Run command
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./mopi.sh %s %s -', FNAME, PKG_DIR));
            assertEqual(0, status);
        case 'matlab'
            % Run the matlab script
            mopi(FNAME, PKG_DIR, false, CACHE_DIR);
        otherwise
            error('Bad argument');
    end
    % Make sure packages were installed
    assertTrue( find_exist(EXPECTED_FILE, EXPECTED_DIR) ~= 0 );
    % Delete testing fixtures
    delete(FNAME);
    rmdir(PKG_DIR, 's');
    rmdir(CACHE_DIR, 's');
end

function test_shellscript_url()
    check_url('shell', 'zip', false);
end

function test_shellscript_url_with_inline_comment()
    check_url('shell', 'zip', true);
end

function test_shellscript_url_targz()
    check_url('shell', 'tar.gz', true);
end

function test_mscript_url()
    check_url('matlab', 'zip', false);
end

function test_mscript_url_with_inline_comment()
    check_url('matlab', 'zip', true);
end

function test_mscript_url_targz()
    moxunit_throw_test_skipped_exception( ...
        'Cant process tarball due to file permission problems.');
    check_url('matlab', 'tar.gz', true);
end

% ---------------------------------------------------------------------
% Test FEX package can be installed, by shell or matlab script
function check_fex(method, includeProtocol)
    % Declare constants
    PKG_NAME = '55540-dummy-package';
    % Setup fixtures
    PKG_DIR = tempname;
    CACHE_DIR = tempname;
    FNAME = [tempname '.txt'];
    EXPECTED_FILE = 'dummy.txt';
    EXPECTED_DIR = fullfile(PKG_DIR, '55540');
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
    % Run command
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./mopi.sh %s %s -', FNAME, PKG_DIR));
            assertEqual(0, status);
        case 'matlab-file'
            % Run the matlab script
            mopi(FNAME, PKG_DIR, false, '.cache');
            rmdir('.cache', 's');
        case 'matlab-str'
            % Run the matlab script
            mopi(PKG_NAME, PKG_DIR, false, '.cache');
            rmdir('.cache', 's');
        case 'matlab-int-id'
            % Run the matlab script on an integer input
            mopi(55540, PKG_DIR, false, '.cache');
            rmdir('.cache', 's');
        case 'matlab-addpath'
            % Run the matlab script, and add path
            mopi(FNAME, PKG_DIR, true, '.cache');
            rmdir('.cache', 's');
            assertFalse(isempty(which(EXPECTED_FILE)));
            % Remove path
            rmpath(genpath(PKG_DIR));
        otherwise
            error('Bad argument');
    end
    % Make sure packages were installed
    assertTrue( find_exist(EXPECTED_FILE, EXPECTED_DIR) ~= 0 );
    % Delete testing fixtures
    delete(FNAME);
    rmdir(PKG_DIR, 's');
    rmdir(CACHE_DIR, 's');
end

function test_shellscript_fex()
    moxunit_throw_test_skipped_exception( ...
        ['Cant access MathWorks certificate for wget when calling through' ...
        ' MATLAB or Octave'' system command.']);
    check_fex('shell', true);
end

function test_shellscript_fex_without_protocol()
    moxunit_throw_test_skipped_exception( ...
        ['Cant access MathWorks certificate for wget when calling through' ...
        ' MATLAB or Octave'' system command.']);
    check_fex('shell', false);
end

function test_mscript_fex()
    check_fex('matlab-file', true);
end

function test_mscript_fex_without_protocol()
    check_fex('matlab-file', false);
end

function test_mscript_fex_str()
    check_fex('matlab-str', true);
end

function test_mscript_fex_int_id()
    check_fex('matlab-int-id', true);
end

function test_mscript_fex_addpath()
    check_fex('matlab-addpath', true);
end

% ---------------------------------------------------------------------
function check_full(method)
    % Setup fixtures
    PKG_DIR = tempname;
    CACHE_DIR = tempname;
    FNAME = [tempname '.txt'];
    % Declare constants
    OCTAVGE_PKG = 'control';
    PKG_LIST = {
        ['forge://' OCTAVGE_PKG];
        'fex://55540-dummy-package';
        'http://www.colorado.edu/conflict/peace/download/peace_essay.ZIP';
    };
    EXPECTED_FILES = {
        fullfile(PKG_DIR, 'peace_essay'), 'civility.htm';
    };
    if strcmp(method, 'matlab-cell')
        EXPECTED_FILES(end+1, :) = {fullfile(PKG_DIR, '55540'), 'dummy.txt'};
    else
        fid = fopen(FNAME, 'w');
        fprintf(fid, '# Packages for testing installation\n');
        fprintf(fid, 'forge://control\n');
        % fprintf(fid, 'fex://55540-dummy-package\n');
        fprintf(fid, 'http://www.colorado.edu/conflict/peace/download/peace_essay.ZIP\n');
        fclose(fid);
    end
    % Delete old fixtures
    if exist(PKG_DIR, 'dir'); rmdir(PKG_DIR, 's'); end
    if exist(CACHE_DIR, 'dir'); rmdir(CACHE_DIR, 's'); end
    if isoctave() && is_continuous_integration() ...
            && ~isempty(pkg('list', OCTAVGE_PKG))
        fprintf('Removing existing copy of %s\n', OCTAVGE_PKG);
        pkg('uninstall', OCTAVGE_PKG);
    end
    % Run command
    switch method
        case 'shell'
            % Run the shell script
            status = system( ...
                sprintf('./mopi.sh %s %s -', FNAME, PKG_DIR));
            assertEqual(0, status);
        case 'matlab'
            % Run the matlab script with a file input
            mopi(FNAME, PKG_DIR, false, CACHE_DIR);
        case 'matlab-cell'
            % Run the matlab script with a cell input
            mopi(PKG_LIST, PKG_DIR, false, CACHE_DIR);
        otherwise
            error('Bad argument');
    end
    % Assert files exist
    for iFile=1:size(EXPECTED_FILES, 1)
        assertTrue( ...
            find_exist(EXPECTED_FILES{iFile, 2}, EXPECTED_FILES{iFile, 1}) ...
                ~= 0, ...
            sprintf('File %s could not be found within directory %s', ...
                EXPECTED_FILES{iFile, 2:1}) ...
            );
    end
    if isoctave()
        assertFalse(isempty(pkg('list', OCTAVGE_PKG)));
    end
    % Delete testing fixtures
    delete(FNAME);
    rmdir(PKG_DIR, 's');
    rmdir(CACHE_DIR, 's');
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
function check_shellscript_error(entry)
    FNAME = 'requirements_testing.txt';
    fid = fopen(FNAME, 'w');
    fprintf(fid, '%s\n', entry);
    fclose(fid);
    status = system(sprintf('./mopi.sh %s', FNAME));
    assertTrue(status~=0);
end

function test_mscript_error_noinput()
    assertExceptionThrown(@()mopi(), 'MOPI:BadInput');
end

function test_shellscript_error_noinput()
    status = system('./mopi.sh');
    assertTrue(status~=0);
end

function test_mscript_error_float()
    assertExceptionThrown(@()mopi(2.5, 'external'), 'MOPI:BadInput');
end

function test_shellscript_error_float()
    check_shellscript_error('2.5');
end

function test_mscript_error_struct()
    Shh.package = 'control';
    assertExceptionThrown(@()mopi(Shh, 'external'), 'MOPI:BadInput');
end

function test_mscript_error_badurl()
    package = 'http://example.com/fakefile';
    assertExceptionThrown(@()mopi(package, 'external'), 'MOPI:NoDownload');
end

function test_shellscript_error_badurl()
    check_shellscript_error('http://example.com/fakefile');
end

function test_mscript_error_badfex()
    package = 'fex://0-fake-fex-id';
    assertExceptionThrown(@()mopi(package, 'external'), 'MOPI:NoDownload');
end

function test_shellscript_error_badfex()
    check_shellscript_error('fex://0-fake-fex-id');
end

function test_mscript_error_badentry()
    package = 'a1$%@b2';
    assertExceptionThrown(@()mopi(package, 'external'), 'MOPI:BadEntry');
end

function test_shellscript_error_badentry()
    check_shellscript_error('a1$%@b2');
end