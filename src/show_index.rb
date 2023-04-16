#!/data/data/com.termux/files/usr/bin/ruby

require("./git_index.rb")


def parse(path)
  io = File.open(path,'r')
  indexFile = GitIndex::IndexFile.new
  indexFile.read(io)
  return indexFile
end


def as_hex(str)
  str.each_byte.map{|b| b.to_s(16)}.join
end


def print_general_info()
  puts("Index File Version: #{index.header.version}")
  puts("Index Entries: #{index.header.nr_of_index_entries}, Extensions: #{index.extensions.size}")
  puts("File Hash:")
  puts("#{as_hex(index.file_hash)}")
end


def print_index_entries()
  puts("Index Entries [#{index.header.nr_of_index_entries}]:")
  for e in index.index_entries
    puts("+ #{e.data.entry_path_name} [#{e.file_stats.file_size} Bytes]")
    puts("#{as_hex(e.data.object_hash)}")
    f = e.data.flags
    puts("assume valid: #{f.assume_valid_flag}, extended: #{f.extended_flag}, stage: #{f.stage_flags}")
  end
end


def print_treecache_ext(ext)
  tc = ext.data.tree_cache
  puts("Tree Cache [#{tc.size}]:")
  for t in tc
    path = t.path.size == 0 ? "./" : t.path
    puts("+ #{path}")
    puts("#{as_hex(t.object_hash)}")
    puts("#entries: #{t.nr_of_covered_index_entries.to_i}, #subtrees: #{t.nr_of_subtrees.to_i}")
  end
end


def print_resolve_undo_ext(ext)
  reuc = ext.data.resolve_undo
  puts("Resolve-Undo [#{reuc.size}]:")
  for rue in reuc
    path = rue.path.size == 0 ? "./" : rue.path
    puts("+ #{path}")
    puts("Stage 1 Mode: [#{rue.stage1}]")
    puts("Stage 1 Obj: [#{as_hex(rue.stage1_obj)}]")
    puts("Stage 2 Mode: [#{rue.stage2}]")
    puts("Stage 2 Obj: [#{as_hex(rue.stage2_obj)}]")
    puts("Stage 3 Mode: [#{rue.stage3}]")
    puts("Stage 3 Obj: [#{as_hex(rue.stage3_obj)}]")
  end
end


def print_ext(ext)
  puts("#{ext.extension_signature} extension [#{ext.extension_size} Bytes]:")
  puts("Data: #{ext.data}")
end


def print_extensions()
  if index.extensions.size > 0
    for e in index.extensions
      id = e.extension_signature
      show_all = args.key?(:all)
      if id == GitIndex::TreeCacheExt::ID
        print_treecache_ext(e)
      elsif id == GitIndex::ResolveUndoExt::ID and show_all
        print_resolve_undo_ext(e)
      elsif show_all
        print_ext(e)
      end
    end
  else
    puts("Extensions: None")
  end
end


def print_index_file(index)
  print_general_info(index)
  puts("")
  print_index_entries(index)
  puts("")
  print_extensions(index)
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
  print_index_file(path)
else
  puts("Index file not found at: #{path}")
end