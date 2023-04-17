# git-index-print

A Ruby command line implementation for parsing and printing the Git index file.

## License

See [LICENSE](LICENSE).

## Introduction

The project consists of a Ruby [module](src/git_index.rb) containing the file format definition based on `BinData` DSL and a [script](src/show_index.rb) for printing the parsed file content to the command line.
The module could be used standalone.

## Install

Prerequisite: Ruby installed.

1. Install required gems:
  `gem install bindata`
   
2. Copy files under `src` to your local machine.
   Either to the root folder of a local Git repository or to any desired location.

3. Ensure the script can be executed.
   On Linux/Unix ensure the shebang path is correct and give the script execution rights using `chmod`.   

## Usuage 

When at the root of a Git repository:
`./show_index.rb`

At an arbitrary location:
`./show_index.rb --path=your/target/path/.git/index`

To check options:
`./show_index.rb --help`

## Known limitations

- Currently only tested with Git version 2.40.0 and version 2 of the index file format.
- Supported extensions: TreeCache, ResolveUndo. Data of other extensions is printed as raw string.
- Support for version 4 of the index file format not implemented.
- Only supports SHA1 based repositories.
- No plans to support sparse-checkout in cone mode.

## Disclosure

The driver for this project was to better understand the internal workings of Git and the format in which the data is stored in the index file.
It also seemed to be a good opportunity to get started with the Ruby programming language which I have not really used before.
Was developed on/for Termux on a LG V30.

## Alternatives:

Similar projects:
- Python based [Gin](https://github.com/sbp/gin).
- C++ based [git-print-index](https://github.com/alexhessemann/git-print-index)

Alternatively the Ruby [rugged](https://github.com/libgit2/rugged) module (using `libgit2`) could be used.

Much of the information could also be queried through Git plumbing commands.
