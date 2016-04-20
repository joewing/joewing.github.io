import os
import re
import sys


ssi_re = re.compile('(.*)<!--#([^\s]+)\s+(.+)-->(.*)')
include_re = re.compile('(.+)=\"(.+)\"')
var_re = re.compile('.*var=\"([^\"]+)\".*')
value_re = re.compile('.*value=\"([^\"]*)\".*')

to_rename = set()


def get_name(file):
    return '{}.html'.format(file[:-6])


def handle_include(dir, value, vars, dest):
    m = include_re.match(value)
    include_type = m.group(1)
    file = m.group(2)
    if include_type == 'virtual':
        if file[0] == '/':
            path = '.{}'.format(file)
        else:
            path = '{}/{}'.format(dir, file)
    else:
        path = '{}/{}'.format(dir, file)
    with open(path, 'r') as f:
        process_content(dir, path, vars, dest)


def handle_set(value, vars):
    var = var_re.match(value).group(1)
    value = value_re.match(value).group(1)
    vars[var] = value


def handle_echo(value, vars, dest):
    var = var_re.match(value).group(1)
    value = vars.get(var)
    if value is not None:
        dest.write(value)


def handle_if(value, vars, dest):
    pass


def handle_directive(dir, key, value, vars, dest):
    if key == 'include':
        handle_include(dir, value, vars, dest)
    elif key == 'set':
        handle_set(value, vars)
    elif key == 'echo':
        handle_echo(value, vars, dest)
    elif key == 'if':
        handle_if(value, vars, dest)
    else:
        print 'ERROR: {} {}'.format(key, value)


def process_content(dir, file, vars, dest):
    with open(file, 'r') as src:
        for line in src:
            m = ssi_re.match(line)
            if m:
                before = m.group(1)
                key = m.group(2)
                value = m.group(3)
                after = m.group(4)
                dest.write(before)
                handle_directive(dir, key, value, vars, dest)
                dest.write(after)
            else:
                dest.write(line)


def process_file(dir, file):
    print 'processing {}'.format(file)
    vars = {}
    temp_name = get_name(file)
    with open(temp_name, 'w') as dest:
        process_content(dir, file, vars, dest)
    to_rename.add((file, temp_name))


def process_dir(dir):
    for entry in os.listdir(dir):
        path = '{}/{}'.format(dir, entry)
        if path.endswith('.shtml'):
            process_file(dir, path)
        elif os.path.isdir(path):
            process_dir(path)


def main():
    process_dir('.')
    for old, new in to_rename:
        os.remove(old)
        os.rename(new, old)


if __name__ == '__main__':
    main()
