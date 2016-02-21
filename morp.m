%morp
%   morp(FNAME)
%     * forge://
%     * fex://
%     * http://, https://, ftp://
%     * 
function morp(input, packages_folder, fixpath, download_folder)
    % Input handling --------------------------------------------------
    if nargin<1 || isempty(input)
        input = fullfile(pwd, 'requirements.txt');
        if ~exist(input, 'file')
            error('MORP:BadInput', ...
                ['No package list input was given, and a' ...
                ' `requirements.txt` file could not found in the present' ...
                ' directory.' ...
                ]);
        end
    end
    if nargin<2 || isempty(packages_folder)
        packages_folder = uigetdir(pwd, ...
            'Select the directory for installing packages');
        if (ischar(packages_folder) && packages_folder == '0') || ...
                packages_folder == 0
            disp('Installation of package list was aborted.');
            return;
        end
    end
    if nargin<3 || isempty(fixpath)
        fixpath = true;
    end
    if nargin<4 || isempty(download_folder)
        download_folder = fullfile(packages_folder, '.cache');
    end
    % Main ------------------------------------------------------------
    % Make directory, if it doesn't exist
    if ~exist(packages_folder, 'dir')
        mkdir(packages_folder);
    end
    % Process the input
    if iscell(input)
        % Deal with each string in the cell array
        for iPackage = 1:length(input)
            install_single(input{iPackage}, packages_folder, ...
                download_folder);
        end

    elseif exist(input, 'file')
        % Deal with each entry in the file
        fid = fopen(input);
        while ~feof(fid)
            entry = fgetl(fid);
            install_single(entry, packages_folder, download_folder);
        end
        fclose(fid);

    elseif ischar(input)
        % Install a single package, or a set of packages from a char matrix
        for iPackage = 1:size(input, 1)
            install_single(input(iPackage,:), packages_folder, ...
                download_folder);
        end

    elseif isnumeric(input)
        % Looks like it is a FEX id as an integer
        if abs(input - round(input)) > eps
            error('MORP:BadInput', 'FEX id input must be an integer');
        end
        install_single(num2str(input), packages_folder, download_folder);

    else
        error('MORP:BadInput', ...
            'Can''t install from class type %s', class(input));

    end
    % Add downloaded packages to path
    if fixpath
        addpath(genpath_custom(packages_folder, {'.cache'; 'tests'}));
    end
end


%isoctave  Determine if the environment is Octave
%   isoctave() true if the operating environment is Octave, otherwise
%   it returns false, indicating the environment is something else
%   (MATLAB, Scilab, FreeMat, etc).
function tf = isoctave()
    % Cache the value because it can't change
    persistent tf_cached;
    % If this is the first call, check if we are in octave.
    % We can tell because the 'OCTAVE_VERSION' function will exist.
    if isempty(tf_cached)
      tf_cached = exist('OCTAVE_VERSION', 'builtin') ~= 0;
    end
    % Set the return value equal to the cached value
    tf = tf_cached;
end


%extract  Extract or decompress a file with unknown compression method
%   extract(FNAME)
function status = extract(fname, output_folder)
    %EXTRACTABLE_EXTS = {'.zip', '.gz', '.tar', '.tgz'};
    % Make sure file exists
    if ~exist(fname, 'file')
        error('File %s does not exist', fname);
    end
    % Try to decompress file based on extension
    % Check if the file is a gzipped tarball
    if ~isempty(regexpi(fname, '.tar.gz$', 'once'))
        % We can just call untar to do both decompression steps
        untar(fname, output_folder);
        status = 0;
        return;
    end
    % Check files with a single extension
    [~, ~, ext] = fileparts(fname);
    switch lower(ext)
        case '.zip'
            unzip(fname, output_folder);
            status = 0;
        case '.gz'
            gunzip(fname, output_folder);
            status = 0;
        case {'.tar', '.tgz'}
            untar(fname, output_folder);
            status = 0;
        otherwise
            % Only on Octave can we unpack other filetypes
            if exist('unpack', 'file')
                %warning('off');
                out = unpack(fname, output_folder);
                %warning('on');
                if ~isempty(out)
                    status = 0;
                    return;
                end
            end
            if nargout>0
                status = 1;
            else
                % Throw an error if status is not being captured
                error('MORP:Extract:NotExtractable', ...
                    'Can''t extract file with extension %s\n', ext);
            end
    end
end


%genpath_custom  Generate toolbox path, ignoring custom directories
%   Provides similar functionality to MathWorks' genpath.m, but
function pth = genpath_custom(d, skip_dirs)
    % Default with no additional directories
    if nargin<2
        skip_dirs = {};
    end

    % Declare which directories we don't want to add to the path
    AVOID_DIRNAMES = {'.'; '..'; 'private'};
    AVOID_DIRNAMES = [AVOID_DIRNAMES(:); skip_dirs(:)];

    % Initialise output path
    pth = '';

    % Generate path based on given root directory
    contents = dir(d);
    if isempty(contents)
        return;
    end

    % Add d to the path if it isn't empty
    pth = [pth d pathsep];

    % Select only directories
    contents = contents(cat(1, contents.isdir));
    % Remove directories we want to avoid
    contents = contents(~ismember({contents.name}, AVOID_DIRNAMES));
    % Remove directories which are for class methods
    contents = contents(~strncmp({contents.name}, '@', 1));
    contents = contents(~strncmp({contents.name}, '+', 1));

    % Descend into contained directories
    for i=1:length(contents)
        % Recursively call this function
        pth = [pth ...
            genpath_custom(fullfile(d, contents(i).name), skip_dirs)];
    end
end


%install_forge  Install a package from Octave Forge
%   install_forge(PACKAGE) installs the package PACKAGE from Forge.
function install_forge(package)
    % If we're not in octave, don't try to install from forge
    if ~isoctave(); return; end
    % Strip out 'forge://' protocol identifier, if present at start
    package = regexprep(package, '^forge://', '');
    % Strip out version specifiers, if present
    package = regexprep(package, '^\([^=<>~! ]*\).*', '$1');
    % Got the package name actual
    fprintf('Installing %s from Octave Forge\n', package);
    % Install, retrying as necessary
    pkg('install', '-auto', '-forge', package);
end


%install_fex  Installs a package from the MATLAB FileExchange
%   
function install_fex(package, packages_folder, download_folder)
    % Strip out 'fex://' protocol identifier, if present at the start
    package = regexprep(package, '^fex://', '');
    % Strip out package name, if present, to get just the numeric ID
    package = regexprep(package, '-.*', '');
    % Got the package ID string actual
    fprintf('Installing package %s from FileExchange\n', package);
    % Set the URL to download from
    BASEURL = 'https://www.mathworks.com/matlabcentral/fileexchange/';
    QUERY = '?download=true';
    URL = [BASEURL package QUERY];
    % % Let install_url do all the work for us
    % install_url(URL);

    % Download package from Matlab Central File Exchange
    dl_destination = fullfile(download_folder, [package '.tmp']);
    if ~exist(download_folder, 'dir'); mkdir(download_folder); end
    [dl_destination, status] = urlwrite(URL, dl_destination);
    % Throw a warning and exit if we couldn't install it
    if status==0
        warning('MORP:NoDownload', ...
            'Could not download package %s from\n\t%s', package, URL);
        return;
    end
    % Unzip the downloaded file
    packagedir = fullfile(packages_folder, package);
    % If the directory doesn't exist, create it
    if ~exist(packagedir, 'dir')
        mkdir(packagedir);
    end
    try
        % Try to unzip - not entirely sure we downloaded a zip file
        unzip(dl_destination, packagedir);
    catch
        % Octave-safe catch
        ME = lasterror();
        if ~strcmp(ME.identifier, 'MATLAB:unzip:invalidZipFile')
            rethrow(ME);
        end
        warning('MORP:UnzippableFex', ...
            'Could not unzip package %s from\n\t%s', package, URL);
        % If the FEX package is not a zip file, it is presumably a single
        % m-file. Just move the file to the package directory.
        copyfile(dl_destination, fullfile(packagedir, [package '.m']));
    end

    % Delete the downloaded zip file
    delete(dl_destination);
end


%install_url  Install a package from a URL
%   Unique resource identifier
function install_url(URL, packages_folder, download_folder)

    % Trim whitespace
    URL = strtrim(URL);

    % Use the URL the determine the filename
    filename = URL;
    % Strip out GET data after first ?
    idx = find(filename=='?', 1, 'first');
    if ~isempty(idx)
        filename = filename(1:(idx-1));
    end
    % Strip out from after last /
    if filename(end)=='/';
        filename = filename(1:end-1);
    end
    idx = find(filename=='/', 1, 'last');
    if ~isempty(idx)
        filename = filename((idx+1):end);
    end

    % Get the package name from the filename
    package = filename;
    % Strip out all extensions
    if package(1)=='.'
        package = package(2:end);
    end
    idx = find(package=='.', 1, 'first');
    if ~isempty(idx)
        package = package(1:(idx-1));
    end

    % Report progress
    fprintf('Downloading %s from URL:\n\t%s\n', package, URL);

    % Download package from URL
    dl_destination = fullfile(download_folder, filename);
    if ~exist(download_folder, 'dir'); mkdir(download_folder); end
    [dl_destination, status] = urlwrite(URL, dl_destination);
    % Throw a warning and exit if we couldn't install it
    if status==0
        warning('MORP:NoDownload', ...
            'Could not download package %s from\n\t%s', package, URL);
        return;
    end
    % Unzip the downloaded file
    packagedir = fullfile(packages_folder, package);
    % If the directory doesn't exist, create it
    if ~exist(packagedir, 'dir')
        mkdir(packagedir);
    end
    % Try to extract from this file - not entirely sure we downloaded a
    % comressed file
    fprintf('Attempting to extract contents from %s', dl_destination);
    status = extract(dl_destination, packagedir);
    if status==0
        fprintf('Sucessfully decompressed file %s\n', dl_destination);
    else
        fprintf('Could not decompress file %s\n', dl_destination);
        disp('I''m assuming that this file isn''t actually an archive.');
        % If we couldn't extract the file, it seems to be a single file.
        % Just move the file to the package directory
        copyfile(dl_destination, fullfile(packagedir, package));
    end

    % Delete the downloaded file
    delete(dl_destination);
end


% install_single
% Given a entry of text, detect which type of package is required
% (forge, fex or url), then install it.
% Inputs
%   string
% Outputs
%   Echos progress
% Returns
%   0 on success
%   1 on failure to download input
%   2 on failure to recognise input
function install_single(entry, packages_folder, download_folder)
    % Strip out whitespace
    entry = strtrim(entry);
    % Skip inputs which are just whitespace or are commented out
    if isempty(entry) || strcmp(entry(1), '#')
        return;
    end
    % Remove in-entry comments from input
    comment_occurances = strfind(entry, ' #');
    if ~isempty(comment_occurances)
        entry = entry(1:comment_occurances(1)-1);
        % Remove trailing spaces from input
        entry = strtrim(entry);
    end
    % Done with prep
    disp('');
    disp(repmat('=', 1, 70));
    disp(entry);
    % Work out what kind of package this entry is
    if ~isempty(regexp(entry, '^forge://', 'once'))
        disp('... is Octave Forge');
        install_forge(entry);

    elseif ~isempty(regexp(entry, '^fex://', 'once'))
        disp('... is FileExchange');
        install_fex(entry, packages_folder, download_folder);

    elseif ~isempty(regexp(entry, '://', 'once'))
        disp('... is URL');
        install_url(entry, packages_folder, download_folder);

    elseif ~isempty(regexp(entry, '^[0-9]+(-|$)', 'once'))
        disp('... is FileExchange');
        install_fex(entry, packages_folder, download_folder);

    elseif ~isempty(regexp(entry, '^[a-ZA-Z0-9]+(=<>~! |$)', 'once'))
        disp('... is Octave Forge');
        install_forge(entry);

    else
        disp('... means nothing to me.');
        return;

    end
end