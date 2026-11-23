function local_file = download_source_rev1(url, dest_folder, tf_redownload, num_retries)
%DOWNLOAD_SOURCE_REV1 Download one file with websave, with bounded retries.
%   local_file = download_source_rev1(url, dest_folder, tf_redownload, num_retries)
%
%   Skips the download when the file already exists, unless tf_redownload is
%   true. A .zip must start with the ZIP signature "PK"; anything else (for
%   example, an HTML "Request Rejected" page from the Census Bureau web
%   firewall) is deleted and retried, then raises an error.

arguments
    url (1,1) string
    dest_folder (1,1) string
    tf_redownload (1,1) logical = false
    num_retries (1,1) double {mustBeInteger, mustBePositive} = 5
end

if ~isfolder(dest_folder)
    mkdir(dest_folder);
end
[~, name, ext] = fileparts(extractBefore(url + "?", "?"));
local_file = fullfile(dest_folder, name + ext);

if isfile(local_file) && ~tf_redownload && is_valid_file(local_file, ext)
    return
end

opts = weboptions("Timeout", 300, "UserAgent", "census_2020_dataset (MATLAB websave)");
last_err = "";
for try_idx = 1:num_retries
    try
        websave(local_file, url, opts);
        if is_valid_file(local_file, ext)
            return
        end
        last_err = "file is not a valid " + ext;
    catch err
        last_err = string(err.message);
    end
    if isfile(local_file)
        delete(local_file);
    end
    pause(2 * try_idx);
end
error("census:download", "Download failed after %d tries: %s (%s)", num_retries, url, last_err);
end

function tf = is_valid_file(f, ext)
% Built-ins considered: unzip would test the archive but extracts it; the
% 2-byte signature check is enough to reject HTML error pages.
d = dir(f);
if isempty(d) || d.bytes == 0
    tf = false;
    return
end
if lower(ext) == ".zip"
    fid = fopen(f, "r");
    sig = fread(fid, 2, "*char")';
    fclose(fid);
    tf = strcmp(sig, 'PK');
else
    tf = true;
end
end
