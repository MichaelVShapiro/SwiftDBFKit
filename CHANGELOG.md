# SwiftDBFKit Change Log

## 1.4 BETA

**WARNING:** This is a beta release. Reading and writing dBase 7 files under this release is NOT recommended to be used in production! Use the [stable release](https://github.com/MichaelVShapiro/SwiftDBFKit) (version 1.3) when in production.

### Added Features

Gave support for reading/writing dBase 7 files (though this is still experimental at the moment). This includes reading/writing memo files with dBase 7.

### Bug fixes

- Minor bug fixes when reading data. Thank you to [@lorrden](https://github.com/lorrden) for helping fix issue #1 (encoding/decoding issues)! Thank you for contributing to the DBFKit framework!!
- Minor bug fix when setting the next available block in DBT files
- Minor bug fix when writing a value in the DBT file that takes up more than what is the largest block size. Thank you to [@wrightd](https://github.com/wrightd) for bringing up the bug and fix (issue #3)! Thank you for contributing to the DBFKit framework!!

### Deprecated Functions

Some functions were deprecated in this release for making use of the library simpler, and the output becomes more accurate. All functions deprecated were replaced with other functions. See README for new usage.

## 1.3

### Added Features

Support for reading/writing timestamp fields. This now means that DBFKit officially supports reading/writing all field types!

Also a few more functions were added to help retrieve blocks in the DBT file more easily. Specifically, one can now extract all the DBT blocks (unmerged when one block stretches over another) and get an array holding all those blocks, or extract the DBT blocks merged (when one block stretches over another) and get a dictionary representation of it all.

### Bug Fixes

A minor bug in the canAddColumns() (part of DBFTable class) function which returned the wrong value.

## 1.2

### Added Features

Support for reading/writing field types:

- Memo/OLE/Binary
- Long/Autoincrement
- Double
                
Support for detecting the encryption flag and incomplete transaction flag has also been added
                
### Other Changes

Improved time complexity and documentation in a few areas.

## 1.1

Minor bug fixes. Also added support for reading/writing deleted records.

## 1.0

Initial release
