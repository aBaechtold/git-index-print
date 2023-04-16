#!/data/data/com.termux/files/usr/bin/ruby


require_relative('git_index')


def parse(path)
  io = File.open(path,'r')
  indexFile = GitIndex::IndexFile.new
  indexFile.read(io)
  return indexFile
end


def as_hex(str)
  str.each_byte.map{|b| b.to_s(16)}.join
end


def print_general_info(index)
  puts("Index File Version: #{index.header.version}")
  puts("Index Entries: #{index.header.nr_of_index_entries}, Extensions: #{index.extensions.size}")
  puts("File Hash:")
  puts("#{as_hex(index.file_hash)}")
end


def print_index_entries(index)
  puts("Index Entries [#{index.header.nr_of_index_entries}]:")
  for e in index.index_entries
    puts("+ #{e.data.entry_path_name} [#{e.file_stats.file_size} Bytes]")
    f = e.data.flags
    puts("Assume valid: #{f.assume_valid_flag}, Extended: #{f.extended_flag}, Stage: #{f.stage_flags}")
    puts("#{as_hex(e.data.object_hash)}")
  end
end


def print_treecache_ext(ext)
  tc = ext.data.tree_cache
  puts("Tree Cache Extension [#{tc.size}]:")
  for t in tc
    path = t.path.size == 0 ? "./" : t.path
    puts("+ #{path}")
    nr_entries = t.nr_of_covered_index_entries.to_i
    puts("Entries: #{nr_entries}, Subtrees: #{t.nr_of_subtrees.to_i}")
    if nr_entries > 0
      puts("#{as_hex(t.object_hash)}")
    else
      puts("<Changed>")
    end
  end
end


def print_resolve_undo_ext(ext)
  reuc = ext.data.resolve_undo
  puts("Resolve-Undo Extension [#{reuc.size}]:")
  for rue in reuc
    path = rue.path.size == 0 ? "./" : rue.path
    puts("+ #{path}")
    puts("Stage 1 Mode: #{rue.stage1}")
    puts("#{as_hex(rue.stage1_obj)}")
    puts("Stage 2 Mode: #{rue.stage2}")
    puts("#{as_hex(rue.stage2_obj)}")
    puts("Stage 3 Mode: #{rue.stage3}")
    puts("#{as_hex(rue.stage3_obj)}")
  end
end


def print_ext(ext)
  puts("#{ext.extension_signature} extension [#{ext.extension_size} Bytes]:")
  puts("Data: #{ext.data}")
end


def print_extensions(index, args)
  nr_of_exts = index.extensions.size
  last_index = nr_of_exts - 1
  if nr_of_exts == 0
    puts("Extensions: None")
  else
    show_all = args.key?(:all)
    for i in 0..last_index
      e = index.extensions[i]
      id = e.extension_signature
      if id == GitIndex::TreeCacheExt::ID
        print_treecache_ext(e)
      elsif id == GitIndex::ResolveUndoExt::ID and show_all
        print_resolve_undo_ext(e)
      elsif show_all
        print_ext(e)
      end
      if i != last_index
        puts('')
      end
    end
  end
end


def print_index_file(index, args)
  print_general_info(index)
  puts('')
  print_index_entries(index)
  puts('')
  print_extensions(index, args)
end


DefaultPath = '.git/index'


def parse_args()
  # TODO: Consider to use the optimist or similar gems
  args = Hash.new
  ARGV.join(' ').scan(/--(\w+)(?:[=:](\S+))?/).each { |v| args[v[0].to_sym] = v[1] }
  return args
end


def show_help_and_exit()
  help_msg = <<HELP
Usuage:  #{File.basename(__FILE__)} [--option[=value]]
  
Options:
  --path={path}  Path to the Git index file.
                 Relative to working directory.
                 Default: #{DefaultPath}
  --all          Show all extensions
                 Default: Only tree cache is shown
HELP
  puts(help_msg)
  exit
end


# Script start:
args = parse_args()

if args.key?(:help)
  show_help_and_exit()
end

path = args.key?(:path) ? args[:path] : DefaultPath

if File.exist?(path)
  index = parse(path)
  print_index_file(index, args)
else
  puts("Index file not found at: #{path}")
end
