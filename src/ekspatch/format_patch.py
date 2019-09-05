from os.path import join

def format_patch_command(start, end, name):
    path = join("../patches", name)
    return "git format-patch -o {path} -n {start}..{end}".format(path=path, start=start, end=end)


