#
# Prints the content of the Git index file (.git/index).
#
# The index file content is version specific.
# See 'https://git-scm.com/docs/index-format'.

require 'bindata'
require "bindata/base_primitive"


module GitIndex

  HashAlgoSize = 20 #SHA1


  class Header < BinData::Record
    endian :big

    string    :file_id,
              :read_length => 4
    virtual   :assert => lambda {file_id == 'DIRC'}
    uint32    :version
    uint32    :nr_of_index_entries

  end


  class FileStats < BinData::Record
    endian  :big
    hide    :unused1

    # File status
    # Time stamps are given relative to Linux epoch (01.01.1970 00:00:00 UTC) and truncated to 4 bytes (as only used for change detection).
    # See also Unix 'stat' command.


    # File meta data last changed
    uint32 :ctime_sec
    uint32 :ctime_nanosec_fraction
    # File content last changed
    uint32 :mtime_sec
    uint32 :mtime_nanosec_fraction
    uint32 :device
    uint32 :inode
    # Mode (4 Bytes) split up into its parts:
    uint16 :mode_upper_16 #just zeros? if yes hide
    bit4  :object_type #only 1000 (regular file) / 1010 (symlink) / 1110 (Git link)
    bit3  :unused1 #all zeros
    bit3  :unix_permissions_owner
    bit3  :unix_permissions_group
    bit3  :unix_permissions_other
    uint32 :uid
    uint32 :gid
    uint32 :file_size

  end


  class IndexEntryFlags < BinData::Record
    endian :big

    # Flags (2 Bytes / 16 bit, 4 Bytes / 32 bit if extended)

    bit1    :assume_valid_flag
    bit1    :extended_flag
    bit2    :stage_flags

    bit12   :length_name

    # Extended flags, only present if :extended_flag != 0 (v3 or higher)
    bit1    :reserved_future1,
            :onlyif => lambda { extended_flag != 0 }
    bit1    :skip_worktree_flag,
            :onlyif => lambda { extended_flag != 0 }
    bit1    :intent_to_add_flag,
            :onlyif => lambda { extended_flag != 0 }
    bit13   :unused2,
            :onlyif => lambda { extended_flag != 0 } #need to be all 0's

  end


  class IndexEntryData < BinData::Record
    endian :big

    string :object_hash,
           :read_length => HashAlgoSize
    index_entry_flags :flags
    stringz :entry_path_name

  end


  class Stringt < BinData::BasePrimitive

    # String of variable length, end marked by a custom token
    # Based on implementation of BinData::Stringz

    optional_parameters :token

    def assign(val)
      super(binary_string(val))
    end

    def snapshot
      result = super
      trim_and_terminate(result).chomp(_token)
    end

  private

    def _token
      eval_parameter(:token)
    end

    def value_to_binary_string(val)
      trim_and_terminate(val)
    end

    def read_and_return_value(io)
      str = ""
      i = 0
      ch = nil

      while ch != _token
        ch = io.readbytes(1)
        str += ch
        i += 1
      end

      trim_and_terminate(str)
    end

    def sensible_default
      ""
    end

    def trim_and_terminate(str)
      result = binary_string(str)
      # Sanitize user input
      truncate_after_first_token!(result)
      append_token_if_needed!(result)
      result
    end

    def truncate_after_first_token!(str)
      str.sub!(/([^#{_token}]*#{_token}).*/, '\1')
    end

    def append_token_if_needed!(str)
      if str.length == 0 || str[-1, 1] != _token 
        str << _token
      end
    end

  end


  class IndexEntry < BinData::Record
    endian :big

    file_stats :file_stats
    index_entry_data :data

    # padding 1-8 0's to align to a multiple of 8 bytes
    # TODO: Make padding optional if version is 4.
    string :padding,
           :read_length => lambda { 8 - ((file_stats.num_bytes + data.num_bytes - 1) % 8) - 1 }

  end


  class TreeCacheEntry < BinData::Record
    endian :big

    stringz :path
    stringt :nr_of_covered_index_entries, :token => "\x20" #= ASCII(32) = " "
    stringt :nr_of_subtrees,
            :token => "\x0a" #= ASCII(10) = "\n"

    string :object_hash,
           :read_length => HashAlgoSize,
           :onlyif => lambda {nr_of_covered_index_entries.to_i >= 0}

  end


  class TreeCacheExt < BinData::Record

    ID = 'TREE'

    mandatory_parameter :size

    endian :big

    array :tree_cache,
          :type => :tree_cache_entry,
          :read_until => lambda { num_bytes >= size }

  end


  class ResolveUndoEntry < BinData::Record
    endian :big

    stringz :path

    stringz :stage1
    stringz :stage2
    stringz :stage3

    string :stage1_obj,
           :read_length => HashAlgoSize,
           :onlyif => lambda {stage1.to_i != 0}
    string :stage2_obj,
           :read_length => HashAlgoSize,
           :onlyif => lambda {stage2.to_i != 0}
    string :stage3_obj,
           :read_length => HashAlgoSize,
           :onlyif => lambda {stage3.to_i != 0}
  end


  class ResolveUndoExt < BinData::Record

    ID = 'REUC'

    mandatory_parameter :size

    endian :big

    array :resolve_undo,
          :type => :resolve_undo_entry,
          :read_until => lambda { num_bytes >= size }

  end


  class IndexExtension < BinData::Record

    endian :big

    # TODO: Add the following extensions
    # Refer to: 
    # - https://git-scm.com/docs/index-format
    # - Git source: https://github.com/git/git
    EXT_SplitIndex = 'link'
    EXT_Untracked = 'UNTR'
    EXT_FileSystemMonitor = 'FSMN'
    EXT_EndOfIndexEntries = 'EOIE'
    EXT_IndexEntryOffsetTable = 'IEOT'
    EXT_SparseDirectoryEntries = 'sdir'

    string :extension_signature,
           :read_length => 4
    uint32 :extension_size
    choice :data,
           :selection => :extension_signature do
      tree_cache_ext TreeCacheExt::ID, :size => :extension_size
      resolve_undo_ext ResolveUndoExt::ID, :size => :extension_size
      string :default, :length => :extension_size
    end
  end


  class IndexFile < BinData::Record

    attr :input_size_bytes

    def get_size_in_bytes
      @input_size_bytes
    end

    # Overrides the Base class method to intercept and determine size of input in Bytes
    def read(io, *args, &block)
      if io.is_a? String
        @input_size_bytes = io.bytesize
      elsif io.is_a? File
        @input_size_bytes = io.size
      else
        raise 'Not supported input type. Is not [File, String]'
      end

      super
    end

    endian :big

    header :header

    # List of index entries:
    # Index entries are sorted in ascending order on the name field,interpreted as a string of unsigned bytes (i.e. memcmp() order, no localization, no special casing of directory separator '/'). Entries with the same name are sorted by their stage field.

    array :index_entries,
          :type => :index_entry,
          :initial_length => lambda { header.nr_of_index_entries }

    # Extensions:
    # Note: 'onlyif' cannot contain a call to num_bytes on self as the sum computation tries to exclude optional data by checking onlyif, thus resulting in a circular call chain and eventually a stack too deep error.
    array :extensions, 
          :type => :index_extension,
          :onlyif => lambda { current_size = header.num_bytes + index_entries.num_bytes; current_size < get_size_in_bytes - HashAlgoSize; },
          :read_until => lambda { num_bytes >= get_size_in_bytes - HashAlgoSize }

    # Integrity signature (hash):
    string :file_hash,
           :read_length => HashAlgoSize

  end

end
