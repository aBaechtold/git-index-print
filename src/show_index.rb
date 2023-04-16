#!/data/data/com.termux/files/usr/bin/ruby

require("./git_index.rb")

def parse(path)
  io = File.open(path,'r')
  indexFile = GitIndex::IndexFile.new
  indexFile.read(io)
  return indexFile
end


def asHex(str)
  str.each_byte.map{|b| b.to_s(16)}.join
end

path = '.git/index'

if File.exist?(path)

  index = parse(path)

  puts("Index File Version: #{index.header.version}")
  puts("")

  # Index Entries
  puts("Entries: #{index.header.nr_of_index_entries}")
  for e in index.index_entries
    puts("+ #{e.data.entry_path_name} [#{e.file_stats.file_size} Bytes]")
    puts("#{asHex(e.data.object_hash)}")
    f = e.data.flags
    puts("assume valid: #{f.assume_valid_flag}, extended: #{f.extended_flag}, stage: #{f.stage_flags}")
  end
  puts("")

  # Extensions
  if index.extensions.size > 0
    puts("Extensions: #{index.extensions.size}")
    for e in index.extensions
      if e.extension_signature == GitIndex::TreeCache::ID
        tc = e.data.tree_cache
        puts("+ Tree Cache [#{tc.size}]")
        for t in tc
          path = t.path.size == 0 ? "./" : t.path
          puts("#{path}")
          puts("#{asHex(t.object_hash)}")
          puts("#entries: #{t.nr_of_covered_index_entries.to_i}, #subtrees: #{t.nr_of_subtrees.to_i}")
        end
      else
        puts("+ #{e.extension_signature} [#{e.extension_size} bytes]")
        puts("#Data: {e.data}")
      end
    end
  else
    puts("Extensions: None")
  end
  puts("")

  puts("File Hash:")
  puts("#{asHex(index.file_hash)}")

else
  puts("Index file does not (yet) exist")
end

