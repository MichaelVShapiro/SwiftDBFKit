#  DBFKit

## About DBFKit
DBFKit is a very easy way to read and write DBF files. It has been implemented completely in Swift, and should work with most modern iOS and MacOS versions.

I decided to make this framework because I was working on a software (obviously I was using Swift to build an application) and I needed to be able to export DBF files. Since there is no framework or library written in Swift that achieves this, I built one.

DBFKit should work with any DBF version (such as FoxPro and dBase III) for both reading and writing. I used the famous python framework [dbfread](https://github.com/olemb/dbfread) to make sure all values can be properly read. Along with the reading capabilities of DBFKit I implemented on my own, I tested it with dbfread to make sure I get the same results.

**NOTE**: DBFKit should also be able to read/write dBase 7 level DBF files -- though this is experimental at the moment.

## Table of Contents

- Installation
- How to use
- Research
- Time Complexity
- License

---

## Installation
### DBFKit - 1.4

To install, download the single "dbf.swift" file and include that in your application to use DBFKit related functions.

DBFKit is designed to work on both MacOS and iOS (any version should work, but later ones are reccomended).

## How to use

I have designed the API to be very easy to use. I will give a demonstration of how to use it here, but for more tutorials on the API, see the "Tutorial" folder.

### The DBFTable

Note that DBF files basically carry databases. These databases have tables which consist of columns and rows. So you will first need to make a table for writing.

```swift
import Foundation

// in order to write to DBF files, you must have a DBF table ready
// little note, when we write/read from DBF files, we are working with tables, dbf files are literally a database!

let table: DBFTable = DBFTable()

// now we start adding columns

table.addColumn(DBFTable.DBFColumn(columnType: .STRING, name: "user", count: 10))
table.addColumn(DBFTable.DBFColumn(columnType: .STRING, name: "role", count: 20))
table.addColumn(DBFTable.DBFColumn(columnType: .STRING, name: "password", count: 20))

// once we are done adding columns, we should lock column adding
table.lockColumnAdding()

// to add rows, we use the addRow function
table.addRow(data: ["John", "admin", "pass"], is_deleted: false)
table.addRow(data: ["Doe", "coordinator", "pass2"], is_deleted: false)
table.addRow(data: ["Anna", "normal_user", "pass3"], is_deleted: false)
```

### Writing

We can use the **DBFWriter** class for easy writing.

```swift

// assume we have already set up the table "variable" from the previous example

let writer: DBFWriter = DBFWriter(dbfTable: table) // we pass in the table we made

// there is only one step left to do, call the write function!
// this can throw errors, so we must execute it in a do-catch block

do {
    try writer.write(to: URL(filePath: "path/to/file.dbf")!)
} catch {
    print("\(error)")
}
```
 ### Reading
 
 We can use the DBFFile class for reading dbf files.
 
 ```swift
 let reader: DBFFile = DBFFile(path: "path/to/file.dbf")
 
 // we need to call the read function to read the file
 // this must be done in a do-catch block
 
do {
    try reader.read() // easy!
    
    // now we can derive the data read by calling the getter to get the table
    
    let theTableRead: DBFTable = reader.getDBFTable()
    print(theTableRead.getColumns())
    print(theTableRead.getRows())
} catch {
    print("\(error)")
}
 ```
 
 ### Reading & Writing with Memo Fields
 
 If you are reading or writing a DBF and at least one Memo field is present, make sure you follow the example below, as it highlights how to do it properly.
 
 ```swift
let table: DBFTable = DBFTable()

// assume we have added some columns, and one of them is of type memo

do {
    // write the file like you normal would
    let writer: DBFWriter = DBFWriter(dbfTable: table)
    
    try writer.write(to: URL(filePath: "path/to/file.dbf")!)
    
    // DBFKit doesn't automatically write to the DBT file for memo fields
    // you have to execute that yourself
    
    try writer.writeDBT(to URL(filePath: "path/to/memo_file.dbt")!)
    
    // for reading memo fields, do the following
    let reader: DBFFile = DBFFile(path: "path/to/file.dbf")
    
    try reader.read()
    
    let index_of_memo: Int = Int(reader.getDBFTable().getRows()[0][0])! // we will assume first column is a memo field
    // all memo fields carry an index of where the actual memo data is stored in the dbt file
    // we just need to extract it using the method below
    
    let memo_data: String = reader.readMemo(file: URL(filePath: "path/to/memo_file.dbt")!, index: index_of_memo)
    print(memo_data)
} catch {
    print("\(error)")
}
 ```
 
 ### Reading & Writing Fields of Type Bool/Date/Timestamp
 
 You may have noticed how the records we input into DBFTable only accepts an array of strings. So data of type bool/date/timestamp need to be converted into a _dbf string_ which DBFKit can understand. The example below illustrates how to do thi.
 
 ```swift
 let dbf_table: DBFTable = DBFTable()
 dbf_table.addColumn(DBFTable.DBFColumn(columnType: .BOOL, name: "test_bool", count: DBFTable.BOOL_COUNT))
 dbf_table.addColumn(DBFTable.DBFColumn(columnType: .DATE, name: "test_date", count: DBFTable.DATE_COUNT))
 dbf_table.addColumn(DBFTable.DBFColumn(columnType: .TIMESTAMP, name: "timestamp", count: DBFTable.TIMESTAMP_COUNT))
 
 dbf_table.lockColumnAdding()
 
let dbf_bool: String = DBFTable.getBoolValue(bool: true)
let dbf_date: String = DBFTable.getDateValue(date: Date())
let dbf_timestamp: String = DBFTable.convertToTimestamp(date: Date())
    
dbf_table.addRow(data: [dbf_bool, dbf_date, dbf_timestamp])

// you can also convert out of the dbf strings using other static functions
do {
    let actual_bool_value: Bool? = DBFTable.getBoolFromDBFValue(dbfValue: "T") // note that sometimes booleans in DBF files can be left uninitialized
} catch {
    print("\(error)")
}

let actual_timestamp_value: Date? = DBFTable.convertTimestampToDate(timestamp: dbf_table.getRows()[0][2])
let actual_date_value: Date? = DBFTable.getDateFromDBFValue(dbf_value: "20251201")
 ```
 
 ### Reading & Writing dBase 7 Level Files
 
 DBFKit can read and write DBF files of different levels, including dBase 7.
 
 _**Note however that reading and writing dBase 7 files with DBFKit is experimental at the moment**. If you are trying to read/write a dBase 7 level file with DBFKit and come across an error DBFKit made, feel free to post an issue._
 
 By default, DBFKit will read/write in dBase 3 level files. You can change this behavior as follows:
 
 ```swift
 // example for writing dBase 7 level file
 let table: DBFTable = DBFTable()
 
 // ... adding columns/rows etc.
 
 // dBase 7 allows you to set FieldProperties
 // this is completely optional and you can skip its set up
 // more info on this will be given later
 
 let writer: DBFWriter = DBFWriter(dbfTable: table)
 
do {
    // configure any other settings you like for dBase 7 file writing
    //NOTE: THESE ARE OPTIONAL SETTINGS -- YOU DON'T HAVE TO FILL THEM OUT AT ALL
    writer.encryption_flag = false // if data you are writing is encrypted
    writer.language_driver_id = 0x00 // All possible values can be found: https://stackoverflow.com/a/52957718
    writer.language_driver_name = "" // See same link
    writer.has_production_mdx_file = false // 99% of the time, you should leave this as false
    writer.has_incomplete_transaction = false // if the database table has an incomplete trasaction (i.e. a database operation that has started but not properly finalized. The flag usually indicates potential data inconsistency or corruption). Once again, 99% of the time, you should leave this to false
    writer.dbt_block_size = 1 // this is only useful in memo fields. It dictates the size of each block in the DBT file
    
    try writer.write(to: URL(filePath: "path/to/file_dbase7.dbf")!, encoding: .utf8, version: .DBASE7) // specifies to write using dBase 7
        
    // reading is also easy
    let file: DBFFile = DBFFile(path: "path/to/dbase7/level/file.dbf")
    
    try file.readDbase7() // also easy!
} catch {
    print("\(error)")
}
 ```
 
 #### Working with Autoincrement Fields
 
 **WARNING**: dBase 7 allows you to read/write autoincrement fields. While most, if not all, DBF editors (or SQL tools rather) will automatically adjust the autoincrement value upon inserting a new row/record, _DBFKIT WILL NOT!_ This is something that should be done manually. This section describes how to do it.
 
```swift
//MARK: - WRITING AUTOINCREMENT FIELDS
 
let table: DBFTable = DBFTable()
table.addColumn(DBFTable.DBFColumn(columnType: .AUTOINCREMENT, name: "test_autoincrement", count: DBFTable.LONG_COUNT, next_autoincrement_value: DBFTable.DEFAULT_AUTOINCREMENT_VALUE)) // technically, it isn't even necessary to include the next_autoincrement_value parameter
// if left out, next_autoincrement_value will default to 1 (or DBFTable.DEFAULT_AUTOINCREMENT_VALUE)
 
table.lockColumnAdding()
 
table.addRow(data: ["1"]) // again, you have to insert the autoincrement values manually
table.addRow(data: ["2"])
 
// now update the column details so the next autoincrement value is reflected
table.incrementAutoIncrementValue(at: 0)
table.incrementAutoIncrementValue(at: 0)
// incrementAutoIncrementValue increments the next auto increment value of a column at a given index
// we call it twice since we are inserting two rows and the next autoincrement value should be 3
// this index is relative to what table.getColumns() returns
 
//MARK: - READING AUTOINCREMENT FIELDS
 
// first read the file
let file: DBFFile = DBFFile(contentsOf: URL(string: "path/to/dbf/file.dbf")!)
 
do {
    try file.readDbase7()
    
    let rows: [String] = file.getDBFTable().getRows() // read autoincrement values from the records
    
    let columns: [DBFTable.DBFColumn] = file.getDBFTable().getColumns()
    
    // go through columns and print the next autoincrement value
    for i in columns {
        if i.columnType == .AUTOINCREMENT {
            print("Column with name \"\(i.name)\" is an autoincrement column, and the next autoincrement value there is \(i.next_autoincrement_value!)")
        }
    }
} catch {
    print("\(error)")
}
```

While the reading autoincrement fields is more straightforward, just remember that writing autoincrement fields requires inserting autoincrement values manually, and calling ```incrementAutoIncrementValue``` to make sure all values are valid.

#### Working with Field Properties

dBase 7 level files allow you to set field properties. This can be used to set constraints for enhanced data integrity and functionality. There are three different types of properties you can set: standard properties, custom properties, and referential integrity. Do note however that it is optional to set these properties.

_**WARNING**: This is an experimental feature in DBFKit, and there is a chance that data could be read or written incorrectly. Feel free to post an issue if you believe you found an error._

## Research

Below are the sources I used to help me implement this.

- https://en.wikipedia.org/wiki/.dbf (contains info about DBF file structure)
- https://www.dbase.com/Knowledgebase/INT/db7_file_fmt.htm (more info on DBF file structure on official dBase website)
- http://www.dbase.com/help/Design_Tables/IDH_TABLEDES_FIELD_TYPES.htm (more info about the different field types)
- https://www.clicketyclick.dk/databases/xbase/format/dbt.html#DBT_STRUCT (DBT file structure info)
- https://www.dbase.com/Knowledgebase/faq/dBASE_Limits_FAQ.html (dBase limitations)

Along with this, I have included the "Developer" folder which showed the process of how I reversed engineered this, and how DBF files are actually written. 

## Time Complexity

I would like discuss the time complexity operations of DBFKit.

### Time Complexity for Writing

Let _n_ be the number of columns in the DBFTable, _m_ be the length of each column, and _r_ be the number of rows in the DBFTable.

The time complexity for writing to a DBF file given a DBFTable is expected to be **O((n \* m) + (r \* n \* m))**.

### Time Complexity for Reading

Let _n_ be the number of columns written in the DBF file, _m_ be the maximum length of each column, and _r_ be the number of rows written.

The time complexity for reading from a given DBF file is expected to be **O((n \* m) + r)**

Generally speaking, DBFKit goes quite fast.

## License

DBFKit is open source! You are free to use it, distribute it, and or modify it. I have licensed this project under MIT (see LICENSE file).
