function manifest = write_manifest_rev1(cfg)
%WRITE_MANIFEST_REV1 Record the size and SHA-256 hash of every source file.
%   manifest = write_manifest_rev1(cfg) writes data/raw/MANIFEST.csv for the
%   downloaded files in the cache folder (not committed) and the raw files
%   committed in data/raw, so a later run can confirm identical inputs.

arguments
    cfg (1,1) struct
end

subs = ["other", "tract", "block", "check"];
files = strings(0, 1);
for s = subs
    f = dir(fullfile(cfg.cache_folder, s, "*.*"));
    f = f(~[f.isdir]);
    files = [files; string(fullfile({f.folder}, {f.name}))']; %#ok<AGROW> few folders
end
r = dir(fullfile(cfg.raw_folder, "**", "*.*"));
r = r(~[r.isdir] & ~strcmp({r.name}, 'MANIFEST.csv'));
files = [files; string(fullfile({r.folder}, {r.name}))'];

num_files = numel(files);
location = strings(num_files, 1);
file_name = strings(num_files, 1);
bytes = zeros(num_files, 1);
sha256 = strings(num_files, 1);
for k = 1:num_files
    [folder, name, ext] = fileparts(files(k));
    file_name(k) = name + ext;
    if startsWith(folder, cfg.raw_folder)
        location(k) = "data/raw" + extractAfter(folder, strlength(cfg.raw_folder));
    else
        [~, sub] = fileparts(folder);
        location(k) = "cache/" + sub;
    end
    info = dir(files(k));
    bytes(k) = info.bytes;
    sha256(k) = sha256_file_rev1(files(k));
end
manifest = sortrows(table(location, file_name, bytes, sha256), ["location", "file_name"]);
writetable(manifest, fullfile(cfg.raw_folder, "MANIFEST.csv"));
end
