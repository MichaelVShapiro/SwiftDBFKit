//
//  dbf.swift
//  DBFKit
//
//  Created by Michael Shapiro on 4/29/24.
//

import Foundation
import OSLog

/**
 * For managing DBF errors
 * - Version: 1.0
 * - Since: 1.0
 */
enum DBFError: Error {
    case COLUMN_ADD_ERR(String), ROW_ADD_ERR(String), READ_ERROR(String)
}

/**
 * A DBF table which stores all the data
 * - Version: 1.1
 * - Since: 1.0
 */
class DBFTable {
    
    /**
     * A column data type
     * - Version: 1.1
     * - Since: 1.0
     */
    enum ColumnType: Character {
        /// Represents the column type string
        /// - Version: 1.0
        /// - Since: 1.0
        case STRING = "C"
        /// Represents the column of type date
        /// - Version: 1.0
        /// - Since: 1.0
        case DATE = "D"
        /// Represents the column of type float (double)
        /// - Version: 1.0
        /// - Since: 1.0
        case FLOAT = "F"
        /// Represents the column of type numeric
        /// - Version: 1.0
        /// - Since: 1.0
        case NUMERIC = "N"
        /// Represents the column of type boolean
        /// - Version: 1.0
        /// - Since: 1.0
        case BOOL = "L"
        /// Represents the column of type memo
        /// - Version: 1.0
        /// - Since: 1.2
        /// > Note: When data is read from a memo field, the location of where the memo block is only recorded in the dbt file. When writing to a dbf file, you can insert normal contents. The memo field simply allows you to insert a string with length > 254. This is stored within a DBT file. The dbt file must have the same name as the dbf file
        case MEMO = "M"
        /// Represents the column of type OLE
        /// - Version: 1.0
        /// - Since: 1.2
        /// > Note: This field acts similar to MEMO. The value this field holds is simply an index to a block in the DBT file
        case OLE = "G"
        /// Represents the column of type binary
        /// - Version: 1.0
        /// - Since: 1.2
        /// > Note: This field is purely identical to OLE (at least in DBF files. In FoxPro, it is different. DBFKit at the moment can only read/write this field as the DBF version)
        case BINARY = "B"
        /// Represents the column of type long (this usually is made available specifically in Visual Fox Pro files)
        /// - Version: 1.0
        /// - Since: 1.2
        /// > Note: There are two characters in DBF files that represent this. They are 'I' and '+'. This data type is always 4 bytes long
        case LONG = "I"
        /// Same as LONG
        /// - Version: 1.0
        /// - Since: 1.2
        /// > Note: The structure and data written is the exact same as of LONG data type. The only difference between the two is that AUTOINCREMENT is supposed to increment the integer written in the record by 1. Note that DBFKit **does not** auto increment this value, but picks it up raw. Autoincrementing should be done manually. Overall, this field acts identical to the auto increment field in SQL databases
        case AUTOINCREMENT = "+"
        /// Represents the column of type double
        /// - Version: 1.0
        /// - Since: 1.2
        /// > Note: This data type is usually stored as 8 bytes in the DBF file. This **does not** mean that that actual value has to be no more than 8 character in size.
        case DOUBLE = "O"
    }
    
    /**
     * We will be using this to manage columns
     * - Version: 1.0
     * - Since: 1.0
     */
    struct DBFColumn {
        /**
         * The column type
         * - Version: 1.0
         * - Since: 1.0
         */
        let columnType: ColumnType
        /**
         * The column name
         * - Version: 1.0
         * - Since: 1.0
         */
        let name: String
        /**
         * The field length. Maximum allowed: 254
         * - Version: 1.0
         * - Since: 1.0
         */
        let count: Int
    }
    
    /**
     * A place to store all the columns
     * - Version: 1.0
     * - Since: 1.0
     */
    private var columns: [DBFColumn] = []
    
    /**
     * Determines if we are allowed to add more columns
     * - Version: 1.0
     * - Since: 1.0
     */
    private var isColumnLocked: Bool = false
    
    /**
     * The rows we are storing
     * - Version: 1.0
     * - Since: 1.0
     */
    private var rows: [[String]] = []
    /**
     * All deleted rows (records) from the dbf file
     * - Version: 1.0
     * - Since: 1.1
     */
    private var deleted_rows: [[String]] = []
    /**
     * The default length of the date field
     * - Version: 1.0
     * - Since: 1.2
     */
    public static let DATE_COUNT: Int = 8
    /**
     * The default length of the bool field
     * - Version: 1.0
     * - Since: 1.2
     */
    public static let BOOL_COUNT: Int = 1
    /**
     * The default length of the memo field
     * - Version: 1.0
     * - Since: 1.2
     * > Note: Memos fields of course can be greater than 10. The length 10 just dictates the length of the index (of how it will appear written in the actual DBF file). When writing any records, the length of the string can go beyond this value. DBFKit will not check its length
     */
    public static let MEMO_COUNT: Int = 10
    /**
     * The default length for the long (and autoincrement) field
     * - Version: 1.0
     * - Since: 1.2
     * > Note: This length doesn't mean the integer length passed in as the value. This length is merely an indicator of how many bytes it takes up in the DBF file
     */
    public static let LONG_COUNT: Int = 4
    /**
     * The default length for the double field
     * - Version: 1.0
     * - Since: 1.2
     * > Note: This length does not mean the double passed in has to be no more than 8 characters in length. The length is merely an indicator of how many bytes it takes up in the DBF file
     */
    public static let DOUBLE_COUNT: Int = 8
    
    /**
     * Locks column adding
     * - Version: 1.0
     * - Since: 1.0
     */
    public func lockColumnAdding() {
        self.isColumnLocked = true
    }
    
    /**
     * Determines if columns can be added. This acts as a simple getter for isColumnLocked
     * - Returns: A boolean indicating if columns can be added
     * - Version: 1.0
     * - Since: 1.0
     */
    public func canAddColumns() -> Bool {
        return self.isColumnLocked
    }
    
    /**
     * Adds a column to the data table. Time complexity: O(1)
     * - Parameters:
     *  - name: Required. The column name to add
     *  - type: Required. The type of data the column conforms to
     *  - len: Required. The field maximum length. Maximum value 254 allowed
     * - Throws: An error if column adding is locked or the column name is not valid
     * - Version: 1.1
     * - Since: 1.0
     */
    public func addColumn(with name: String, dataType type: ColumnType, count len: Int) throws {
        // make sure we are allowed to add columns to the list
        if self.isColumnLocked {
            throw DBFError.COLUMN_ADD_ERR("Cannot add columns to DBF table because column adding is locked")
        }
        // make sure name has at least one valid character in it
        if name.replacingOccurrences(of: " ", with: "") == "" {
            throw DBFError.COLUMN_ADD_ERR("The column name must not be empty and have at least one valid character")
        }
        
        // fix the column lengths for fields that have a set length
        var lenm: Int = len // mutable version
        if (type == .MEMO || type == .BINARY || type == .OLE) && lenm != DBFTable.MEMO_COUNT {
            lenm = DBFTable.MEMO_COUNT
            os_log("Incorrect Memo/Binary/OLE field length given \"\(len)\". It was auto-corrected to \(DBFTable.MEMO_COUNT) {DBFTable.MEMO_COUNT}")
        } else if (type == .AUTOINCREMENT || type == .LONG) && lenm != DBFTable.LONG_COUNT {
            lenm = DBFTable.LONG_COUNT
            os_log("Incorrect Autoincrement/Long field length given \"\(len)\". It was auto-corrected to \(DBFTable.LONG_COUNT) {DBFTable.LONG_COUNT}")
        } else if type == .DOUBLE && lenm != DBFTable.DOUBLE_COUNT {
            lenm = DBFTable.DOUBLE_COUNT
            os_log("Incorrect Double field length given \"\(len)\". It was auto-corrected to \(DBFTable.MEMO_COUNT) {DBFTable.DOUBLE_COUNT}")
        } else if type == .BOOL && lenm != DBFTable.BOOL_COUNT {
            lenm = DBFTable.BOOL_COUNT
            os_log("Incorrect Bool field length given \"\(len)\". It was auto-corrected to \(DBFTable.BOOL_COUNT) {DBFTable.BOOL_COUNT}")
        } else if type == .DATE && lenm != DBFTable.DATE_COUNT {
            lenm = DBFTable.DATE_COUNT
            os_log("Incorrect Date field length given \"\(len)\". It was auto-corrected to \(DBFTable.DATE_COUNT) {DBFTable.DATE_COUNT}")
        }
        
        // make sure len is in proper amount
        if (lenm < 1 || lenm > 254) {
            throw DBFError.COLUMN_ADD_ERR("Invalid number given for column length. Length should be 1 <= x <= 254 and is \(len)")
        }
        self.columns.append(DBFColumn(columnType: type, name: name, count: lenm))
    }
    
    /**
     * Adds a row to the DBF table. Time complexity: O(1)
     * - Parameters:
     *  - data: Required. An array of string to add for the data
     * - Throws: An error if the adding column property is not locked or if the number of values in data is not the same as the number of columns
     * - Version: 1.0
     * - Since: 1.0
     */
    public func addRow(with data: [String]) throws {
        // make sure adding columns is locked
        if !self.isColumnLocked {
            throw DBFError.ROW_ADD_ERR("Cannot add rows to the table because adding columns is not locked")
        }
        // make sure the length of data is the same as the number of columns in the table
        if data.count != self.columns.count {
            throw DBFError.ROW_ADD_ERR("Cannot add a row to the table because it does not have the same number of values as the number of columns added in the table. Row value count: \(data.count), Column count: \(self.columns.count)")
        }
        // now add
        self.rows.append(data)
    }
    /**
     * Adds a row to the DBF table. Time complexity: O(1)
     * - Parameters:
     *  - data: Required. An array of string to add for the data
     *  - deleted: Optional. If the row (record) is deleted
     * - Throws: An error if the adding column property is not locked or if the number of values in data is not the same as the number of columns
     * - Version: 1.0
     * - Since: 1.1
     */
    public func addRow(with data: [String], deleted: Bool) throws {
        // make sure adding columns is locked
        if !self.isColumnLocked {
            throw DBFError.ROW_ADD_ERR("Cannot add rows to the table because adding columns is not locked")
        }
        // make sure the length of data is the same as the number of columns in the table
        if data.count != self.columns.count {
            throw DBFError.ROW_ADD_ERR("Cannot add a row to the table because it does not have the same number of values as the number of columns added in the table. Row value count: \(data.count), Column count: \(self.columns.count)")
        }
        // check if record is deleted
        if deleted {
            // add to list of deleted rows
            self.deleted_rows.append(data)
            return
        }
        // now add
        self.rows.append(data)
    }
    
    /**
     * A simple getter for the columns added
     * - Returns: An array of all columns added
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getColumns() -> [DBFColumn] {
        return self.columns
    }
    
    /**
     * A simple getter for the rows
     * - Returns: An array of all rows added
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getRows() -> [[String]] {
        return self.rows
    }
    /**
     * A simple getter for deleted rows (records)
     * - Returns: An array of all rows which were removed from the dbf file
     * - Version: 1.0
     * - Since: 1.1
     */
    public func getDeletedRows() -> [[String]] {
        return self.deleted_rows
    }
    
    /**
     * Gets the total number of bytes the table will take up in the DBF file. Time complexity: O(n) where n is the number of columns
     * - Returns: A number indicating the number of bytes needed to write up the DBF file
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getTotalBytes() -> Int {
        var totalBytes: Int = 31
        // we need to get the number of bytes per record
        // go over each column and multiply each col expected total by the record count
        for i in self.columns {
            // one column already takes up 31 bytes of data
            totalBytes += 31
            totalBytes += i.count * self.rows.count
        }
        // add bytes to include spaces for separating rows
        totalBytes += self.rows.count
        // include another byte for col terminator
        totalBytes += 7
        return totalBytes
    }
    
    /**
     * Gets the total number of bytes the header of the table will take up in the DBF file. Time complexity: O(1)
     * - Returns: An integer representing how many bytes the header takes up
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getTotalBytesHeader() -> Int {
        var totalBytes: Int = 32 * self.columns.count + 1
        totalBytes += 32
        return totalBytes
    }
    
    /**
     * Gets the total number of bytes per record of the table that will take up in the DBF file. Time complexity: O(n) where n is the number of columns
     * - Returns: An integer representing how many bytes all the rows will take up
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getTotalBytesPerField() -> Int {
        var totalBytes: Int = 0
        for i in self.columns {
            totalBytes += i.count
        }
        totalBytes += 1
        totalBytes = totalBytes * self.rows.count
        return totalBytes
    }
    /**
     * Gets the total number of bytes one record takes up in the DBF file. Time complexity: O(n) where n is the number of columns
     * - Returns: An integer representing how many bytes on record (row) will take up
     * - Version: 1.0
     * - Since: 1.1
     */
    public func getTotalBytesOneRecord() -> Int {
        // add up all field count
        var totalBytes: Int = 0
        for i in self.columns {
            totalBytes += i.count
        }
        totalBytes += 1
        return totalBytes
    }
    /**
     * Gets the total number of records (both deleted and not deleted) in the table
     * - Returns: An integer representing how many records there are
     * - Version: 1.0
     * - Since: 1.1
     */
    public func getTotalRecordCount() -> Int {
        return self.rows.count + self.deleted_rows.count
    }
    
    /**
     * Gets the character of how a boolean would appear in the table. This should mainly be used to convert the boolean into a string, to which you want to insert into the row
     * > We use this function when you are trying to insert a boolean value into a particular row index. For instance, if a specific column accepts the value of boolean, you will need to convert your boolean into a string value the DBFTable (and the DBF file ultimately) can interpret. This function does the conversion for you
     * - Returns: A DBF representation of the boolean
     * - Version: 1.0
     * - Since: 1.0
     */
    public static func getBoolValue(bool value: Bool?) -> String {
        if value == nil {
            return "?" // uninitialized
        }
        if value! {
            return "T"
        }
        return "F"
    }
    
    /**
     * This function acts similarlily to getBoolValue, except it does it for the date!
     * - Parameters:
     *  - date: Required. The date to convert into DBF representation
     * - Returns: A DBF representation of the date
     * - Version: 1.0
     * - Since: 1.0
     */
    public static func getDateValue(date: Date) -> String {
        var d: String = ""
        let c: DateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y: Int = c.year!
        let m: Int = c.month!
        let dd: Int = c.day!
        let ms: String = (m < 10 ? "0" : "") + String(m)
        let ds: String = (dd < 10 ? "0" : "") + String(dd)
        d += "\(y)\(ms)\(ds)"
        return d
    }
    
    /**
     * Gets the boolean value given a DBF boolean
     * - Parameters:
     *  - dbfValue: Required. The character to convert from DBF file bool
     * - Returns: A boolean or nil (if the dbfValue was uninitialized)
     * - Throws: An error if the character is invalid
     * - Version: 1.1
     * - Since: 1.0
     */
    public static func getBoolFromDBFValue(dbfValue: Character) throws -> Bool? {
        if dbfValue == "?" || dbfValue == " " {
            return nil
        }
        if dbfValue.lowercased() == "t" || dbfValue.lowercased() == "y" {
            return true
        } else if dbfValue.lowercased() == "f" || dbfValue.lowercased() == "n" {
            return false
        }
        throw DBFError.READ_ERROR("Unknown DBF bool value \"\(dbfValue)\" given")
    }
}

/**
 * The core writer class
 * - Version: 1.1
 * - Since: 1.0
 */
class DBFWriter {
    
    /**
     * A dbf table to write from
     * - Version: 1.0
     * - Since: 1.0
     */
    public var dbfTable: DBFTable
    /**
     * Sets the encryption flag in the DBF file
     * - Version: 1.0
     * - Since: 1.2
     * > Note: this variable in no way encrypts and/or decrypts the table in the dbf file. It is just an indicator (i.e. marks the encryption flag). It automatically defaults to false (no encryption)
     */
    public var encryption_flag: Bool = false
    /**
     * This is where the dbt file would be written
     * - Version: 1.0
     * - Since: 1.2
     */
    private var dbt_data: Data? = nil
    /**
     * The next available index for the dbt block
     * - Version: 1.0
     * - Since: 1.2
     */
    private var dbt_next_block_index: Int = 1
    
    /**
     * Initializes the DBFWriter with a given table
     * - Parameters:
     *  - dbfTable: Required. The dbf table that will be written
     * - Version: 1.0
     * - Since: 1.0
     */
    init(dbfTable: DBFTable) {
        self.dbfTable = dbfTable
    }
    
    /**
     * Initializes the dbt data
     * - Version: 1.0
     * - Since: 1.2
     */
    private func initDBT() {
        // this function assumes that upon initialization, there is at least one field in the dbf table that makes use of memo fields
        // so for now we will intialize this dbt data with two blocks
        // one block consists of 512 bytes in it
        self.dbt_data = Data(count: 512)
        
        // we only put one thing in the header, the next index where data can be inserted
        // in our case, this is simply one
        self.dbt_data![0] = 1
        
        // set version to dBase III
        self.dbt_data![16] = 0x03
    }
    /**
     * Resets the dbt\_data info
     * - Version: 1.0
     * - Since: 1.2
     */
    private func deinitDBT() {
        self.dbt_data = nil
        self.dbt_next_block_index = 1
    }
    /**
     * Writes the given memo into the dbt block
     * - Parameters:
     *  - memo: Required. The data to write
     * - Version: 1.0
     * - Since: 1.2
     */
    private func writeBytesDBT(memo: String) {
        // intialize dbt data if needed
        if self.dbt_data == nil {
            self.initDBT()
        }
        // lets first convert our string memo into the data buffer. We will convert all the characters into ascii character like we have done so far with regular data
        var data: Data = memo.data(using: .ascii)!
        
        // one dbt block consists of 512 bytes
        // first, lets see if the current data we write exceeds this
        if data.count >= 510 { // we compare it to 510 because the last two bytes of the block must represent the end of block
            // we need to figure out how many blocks this stretches over
            let block_count: Int = Int(ceil(Double(data.count) / 512.0))
            
            // update next available block add
            self.dbt_next_block_index = block_count + 1
            
            // our block numbers may not look very nice now
            // one block should have exactly 512 bytes in it
            // since this data right now expands over 1 block, we need to figure out exactly how many bytes to add, so that number is divisible by 512
            let num_bytes_add: Int = data.count % 512
            data.append(Data(count: num_bytes_add))
            data[data.count - 1] = 0x1A
            data[data.count - 2] = 0x1A
            
            // now append to dbt_data
            self.dbt_data!.append(data)
            
            // lastly set the new byte 0 to whatever dbt_data is
            self.dbt_data![0] = UInt8(self.dbt_next_block_index)
        } else {
            // in that case, we set the last two bytes of data to 0x1A (this represents the end of the memo)
            // then append it to dbt_data
            data.append(Data(count: 512 - data.count))
            data[data.count - 1] = 0x1A
            
            self.dbt_data!.append(data)
            
            // increment next available index
            self.dbt_next_block_index += 1
            
            // and set that to byte 0 of dbt_data
            self.dbt_data![0] = UInt8(self.dbt_next_block_index)
        }
    }
    /**
     * Returns the string representation of the dbt block
     * - Returns: A string representation of the index of the dbt block number
     * - Version: 1.0
     * - Since: 1.2
     */
    private func getMemoIndex() -> String {
        // this string should be exactly 10 characters long
        // but we will take care of that when writing the actual data
        return "\(self.dbt_next_block_index)"
    }
    /**
     * Writes a record to a buffer
     * - Parameters:
     *  - buffer: Required. A pointer to a buffer to write to
     *  - record: The record to write
     * - Throws: An error on failure
     * - Version: 1.1
     * - Since: 1.1
     */
    private func writeBytesRecord(buffer: UnsafeMutablePointer<Data>, record: [String], current_offset: UnsafeMutablePointer<Int>) throws {
        // this function already assumes that the record was already marked with an '*' or ' '
        // all text should also be in ascii
        var zi: Int = 0
        for z in record {
            // first check if this field is long or autoincrement
            if self.dbfTable.getColumns()[zi].columnType == .AUTOINCREMENT || self.dbfTable.getColumns()[zi].columnType == .LONG {
                // store int as 4 bytes
                let inti: Int? = Int(z)
                if inti == nil {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) is not an integer")
                }
                
                let inti32: Int32 = Int32(inti!)
                
                // the following was adapted to convert an integer into 4 bytes of uint8
                // https://stackoverflow.com/questions/57670865/convert-int-to-array-of-uint8-in-swift
                let bb: [UInt8] = withUnsafeBytes(of: inti32, Array.init)
                
                for i in 0..<4 {
                    buffer.pointee[current_offset.pointee] = bb[i]
                    current_offset.pointee += 1
                }
                zi += 1
                continue
            } else if self.dbfTable.getColumns()[zi].columnType == .MEMO {
                // the index of the dbt block number if stored as a string
                var index: String = self.getMemoIndex()
                
                // this index is right justified
                // so the remaining n number of spaces should be filled with blanks
                while index.count < 10 {
                    index = "0" + index
                }
                
                for j in index {
                    buffer.pointee.withUnsafeMutableBytes { (bytess: UnsafeMutableRawBufferPointer) in
                        bytess.storeBytes(of: UInt16(j.asciiValue!), toByteOffset: current_offset.pointee, as: UInt16.self)
                    }
                    current_offset.pointee += 1
                }
                
                // now write to dbt data
                self.writeBytesDBT(memo: z)
                zi += 1
                
                continue
            } else if self.dbfTable.getColumns()[zi].columnType == .DOUBLE {
                // validate that our value is a real double
                if Double(z) == nil {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) is not a valid double")
                }
                
                var d: Float64 = Float64(z)! // we store as float64 to force the conversion to 8 bytes exactly
                
                let dd: [UInt8] = withUnsafeBytes(of: &d, Array.init)
                
                for j in dd {
                    buffer.pointee[current_offset.pointee] = j
                    current_offset.pointee += 1
                }
                
                zi += 1
                continue
            } else if self.dbfTable.getColumns()[zi].columnType == .NUMERIC || self.dbfTable.getColumns()[zi].columnType == .FLOAT {
                // validate that z is a real number
                let type: DBFTable.ColumnType = self.dbfTable.getColumns()[zi].columnType
                var value: String = z + ""
                if type == .NUMERIC {
                    if Int(value) == nil {
                        throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) is not a valid number")
                    }
                } else {
                    // check float
                    if Double(value) == nil {
                        throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) is not a valid number")
                    }
                }
                // pad with blanks
                while value.count < self.dbfTable.getColumns()[zi].count {
                    value = " " + value
                }
                
                for j in value {
                    buffer.pointee.withUnsafeMutableBytes { (bytess: UnsafeMutableRawBufferPointer) in
                        bytess.storeBytes(of: UInt16(j.asciiValue!), toByteOffset: current_offset.pointee, as: UInt16.self)
                    }
                    current_offset.pointee += 1
                }
                
                zi += 1
                
                continue
            } else {
                // make sure z is not larger than the max length allowed for the column
                if z.count > self.dbfTable.getColumns()[zi].count {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) exceeds the maximum length for column")
                }
                for j in z {
                    // should be 16 bit
                    buffer.pointee.withUnsafeMutableBytes { (bytess: UnsafeMutableRawBufferPointer) in
                        bytess.storeBytes(of: UInt16(j.asciiValue!), toByteOffset: current_offset.pointee, as: UInt16.self)
                    }
                    current_offset.pointee += 1
                }
            }
            // add spaces until we reach the max length for col
            let space_add: Int = self.dbfTable.getColumns()[zi].count - z.count
            var zzi: Int = 0
            while zzi < space_add {
                buffer.pointee.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                    bytes.storeBytes(of: UInt16(0x0000), toByteOffset: current_offset.pointee, as: UInt16.self)
                }
                current_offset.pointee += 1
                zzi += 1
            }
            zi += 1
        }
    }
    
    /**
     * Writes up the bytes for the dbf data. Time complexity: O((n \* m) + (r \* n \* m)) where n is the number of columns, m is the maximum length of each column, and r is the number of rows
     * - Returns: A buffer
     * - Throws: An error on write
     * - Version: 1.2
     * - Since: 1.0
     */
    private func writeBytes() throws -> Data {
        // reset dbt info as needed
        self.deinitDBT()
        let header_len: Int = self.dbfTable.getTotalBytesHeader()
        let bytes_len: Int = self.dbfTable.getTotalBytesPerField()
        let one_record_len: Int = self.dbfTable.getTotalBytesOneRecord()
        let buffer_len: Int = header_len + bytes_len + 1
        let num_records: Int = self.dbfTable.getTotalRecordCount()
        var buffer: Data = Data(repeating: 0, count: buffer_len)
        // write up header
        // byte 0 should be dbf version
        buffer[0] = 0x03
        // byte 1-3 should be date of last update
        buffer[1] = UInt8((Calendar.current.component(.year, from: Date())) - 1900)
        buffer[2] = UInt8((Calendar.current.component(.month, from: Date())))
        buffer[3] = UInt8(Calendar.current.component(.day, from: Date()))
        // number of records in the table
        buffer.withUnsafeMutableBytes { (bytess: UnsafeMutableRawBufferPointer) in
            bytess.storeBytes(of: UInt32(num_records.littleEndian), toByteOffset: 4, as: UInt32.self)
        }
        // length of header
        buffer.withUnsafeMutableBytes { (bytess: UnsafeMutableRawBufferPointer) in
            bytess.storeBytes(of: UInt16(header_len.littleEndian), toByteOffset: 8, as: UInt16.self)
        }
        // number of bytes per record
        buffer.withUnsafeMutableBytes { (bytess: UnsafeMutableRawBufferPointer) in
            bytess.storeBytes(of: UInt16(one_record_len.littleEndian), toByteOffset: 10, as: UInt16.self)
        }
        
        // mark encryption flag
        if self.encryption_flag {
            buffer[15] = 1
        }
        
        // columns (field descriptors)
        let cols: [DBFTable.DBFColumn] = self.dbfTable.getColumns()
        // loop over all cols and set them up
        var current_offset: Int = 32
        var byteoff: Int = 32
        for i in cols {
            // field name (in ascii)
            // in order to achieve this in ascii, we have to loop over each character and get the ascii char code
            for z in i.name {
                buffer[current_offset] = z.asciiValue!
                // adjust offset as needed
                current_offset += 1
            }
            let byteCont: Int = 11 - i.name.count
            current_offset += byteCont
            // starting from byte 43 (11)
            // field type (also should be in ascii)
            buffer[current_offset] = i.columnType.rawValue.asciiValue!
            // reserved
//            current_offset += 2
            // include max count
            buffer.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                bytes.storeBytes(of: UInt16(i.count), toByteOffset: current_offset + 5, as: UInt16.self)
            }
            byteoff += 32
            current_offset = byteoff
        }
        // field descriptor array terminator
        buffer[current_offset] = 0x0D
        // now load records
        current_offset += 1
//        buffer[current_offset + 1] = 0x0020
//        current_offset += 2
        for i in self.dbfTable.getRows() {
            // add space to mark row present
            buffer[current_offset] = 0x0020
            current_offset += 1
            try self.writeBytesRecord(buffer: &buffer, record: i, current_offset: &current_offset)
        }
        // add any deleted rows
        for i in self.dbfTable.getDeletedRows() {
            // deleted rows are marked with an '*'
            buffer[current_offset] = 0x2A
            current_offset += 1
            try self.writeBytesRecord(buffer: &buffer, record: i, current_offset: &current_offset)
        }
        // eof flag
        buffer[current_offset] = 0x1A
        
        // we will make one last edit
        // if a dbt was written, we must reflect that in byte 0
        if self.dbt_data != nil {
            buffer[0] = 0x83 // this represents DBF version 3 + included DBT file
        }
        
        return buffer
    }
    
    /**
     * Writes to a given DBF file.
     * - Parameters:
     *  - file: Required. A URL to the file to write the DBF data to
     * - Throws: An error on write
     * - Version: 1.0
     * - Since: 1.0
     */
    public func write(to file: URL) throws {
        // get bytes
        let buffer: Data = try self.writeBytes()
        // write to url
        try buffer.write(to: file)
    }
    /**
     * Writes any memo field data written to a given DBT file
     * - Parameters:
     *  - file: Required. A URL to the file to write the DBT data to
     * - Throws: An error on write
     * - Version: 1.0
     * - Since: 1.2
     * > Note: This function **should only be called after executing "write" function.** Essentially, if there are any fields in the DBTTable with type MEMO, this is where this function needs to be called. Memo fields are fields with strings that have a length > 254. All these strings are written in a separate file, which this function is responsible for writing to. Typically, DBT files have an identical name to the DBF file.
     */
    public func writeDBT(to file: URL) throws {
        // lets make sure the dbt table is not nil
        if self.dbt_data == nil {
            throw DBFError.ROW_ADD_ERR("Cannot write a DBT file because no identical DBF file was written")
        }
        
        try self.dbt_data!.write(to: file)
        
        // now deinit the table
        self.deinitDBT()
    }
}

// MARK: DBF READER

/**
 * A simple DBF file
 * - Version: 1.1
 * - Since: 1.0
 */
class DBFFile {
    
    // we will reserve a few variables blank (nil) until the file has been actually read
    
    /**
     * The DBF version being used. This automatically defaults to 3
     * - Version: 1.0
     * - Since: 1.0
     */
    private var dbfVersion: UInt8 = 0x03
    /**
     * Date of last update
     * - Version: 1.0
     * - Since: 1.0
     */
    private var lastUpdate: Date?
    /**
     * Our DBF table
     * - Version: 1.0
     * - Since: 1.0
     */
    private var dbfTable: DBFTable
    /**
     * A path to the DBF file
     * - Version: 1.0
     * - Since: 1.0
     */
    private var filePath: String?
    
    /**
     * The number of records read
     * - Version: 1.0
     * - Since: 1.0
     */
    private var numRecords: Int?
    /**
     * Determines if the contents of the dbf file are encrypted
     * - Version: 1.0
     * - Since: 1.2
     * > Note: This variable in no way encrypts or decrypts the contents of the dbf file. It is merely an indicator of the encryption flag in the DBF file
     */
    public var is_encrypted: Bool = false
    /**
     * Determines if there is an incomplete transaction in the dbf file
     * - Version: 1.0
     * - Since: 1.2
     * > Note: This variable is merely an indicator if the incomplete transaction flag has been detected
     */
    public var incomplete_transaction: Bool = false
    
    /**
     * This will initialize the DBF File with an empty DBF Table
     * - Parameters:
     *  - path: Required. The path to the DBF file
     * - Version: 1.0
     * - Since: 1.0
     */
    init(path: String) {
        // initialize empty table
        self.filePath = path
        self.dbfTable = DBFTable()
    }
    
    /**
     * This will initialize the DBF File with a given table
     *
     *> Warning! This constructor will **not** allow you read a file. It is here for future development purposes
     * - Parameters:
     *  - dbf: Optional. A custom table to pass in
     * - Version: 1.0
     * - Since: 1.0
     */
    init(dataTable dbf: DBFTable) {
        self.dbfTable = dbf
    }
    
    /**
     * A simple getter for the DBF table
     * - Returns: The DBF table read
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getDBFTable() -> DBFTable {
        return self.dbfTable
    }
    
    /**
     * Gets the date of the last update made
     * - Returns: The date of the last update or nil if no dbf file was opened
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getLastUpdate() -> Date? {
        return self.lastUpdate
    }
    
    /**
     * Gets the version of the DBF file
     * - Returns: The version of the DBF file read
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getVersion() -> UInt8 {
        return self.dbfVersion
    }
    
    /**
     * Gets the number of records read
     * - Returns: The number of records read
     * - Version: 1.0
     * - Since: 1.0
     */
    public func getNumRecords() -> Int? {
        return self.numRecords
    }
    
    /**
     * Reads the DBF file given. Time complexity: O((n \* m) + r) where n is the number of columns written, m is the length of each column name, and r is the number of rows
     * - Throws: An error on read
     * - Version: 1.1
     * - Since: 1.0
     */
    public func read() throws {
        // make sure we have a valid path given
        if self.filePath == nil {
            throw DBFError.READ_ERROR("Cannot read DBF file because path is nil")
        }
        // also make sure path given is valid url
        if URL(string: self.filePath!) == nil {
            throw DBFError.READ_ERROR("Invalid file path given: \(self.filePath!)")
        }
        // open the file
//        let buffer: Data = try Data(contentsOf: URL(string: self.filePath!)!)
        let buffer: Data = try Data(contentsOf: URL(filePath: self.filePath!))
        // byte 0 should be version
        let version: UInt8 = buffer[0]
        self.dbfVersion = version
        // next three bytes should be date of last update
        let yearUpdate: Int = Int(buffer[1]) + 1900
        let monthUpdate: Int = Int(buffer[2])
        let dayUpdate: Int = Int(buffer[3])
        var dateComp: DateComponents = DateComponents()
        dateComp.year = yearUpdate
        dateComp.month = monthUpdate
        dateComp.day = dayUpdate
        self.lastUpdate = Calendar(identifier: .gregorian).date(from: dateComp)
        
        // next should be number of records
        let rec: Int = Int(buffer[4])
        self.numRecords = rec
        
        // byte 14 should be a flag for incomplete transaction
        let it: Int = Int(buffer[14])
        // it (or byte 14) must either be 1 or 0
        if it != 1 && it != 0 {
            throw DBFError.READ_ERROR("Invalid incomplete transaction flag: \(it)")
        }
        self.incomplete_transaction = it == 1
        
        // byte 15 should be a flag indicating encryption
        let enc: Int = Int(buffer[15])
        // this should also be either 1 or 0
        if enc != 1 && enc != 0 {
            throw DBFError.READ_ERROR("Invalid encryption flag: \(enc)")
        }
        self.is_encrypted = enc == 1
        
        // use byte 10 for future comparison
        let one_record_bytes: Int = Int(buffer[10])
        
        // it is perfectly safe to skip to byte 32 where the col info begins
        // keep on collecting col info until the terminator is reached
        var current_byte: Int = 32
        var bytec: Int = 32
        var expected_record_count: Int = 1
        while buffer[current_byte] != 0x0D {
            // byte 0-10 is field name (32-42)
            var field_name: String = ""
            let maxFieldNameLen: Int = 11
            // keep on collected field name until 0x00 (space) is reached
            while buffer[current_byte] != 0x00 {
                field_name += String(UnicodeScalar(buffer[current_byte]))
                current_byte += 1
            }
            let toType: Int = maxFieldNameLen - field_name.count
            // next is field type
//            let field_type: Character = Character(UnicodeScalar(buffer[43]))
            let field_type: Character = Character(UnicodeScalar(buffer[current_byte + toType]))
            // make sure character is valid
            if DBFTable.ColumnType.init(rawValue: field_type) == nil {
                throw DBFError.READ_ERROR("Unknown DBF data type \(field_type). Please make sure it is supported")
            }
//            let byteLenStart: Int = 16
            // get field length
            let field_len = buffer[current_byte + toType + 5]
            expected_record_count += Int(field_len)
            // we don't need anymore data than this
            try self.dbfTable.addColumn(with: field_name, dataType: .init(rawValue: field_type)!, count: Int(field_len))
            bytec += 32
            current_byte = bytec
        }
        // make sure expected record count matches what was written earlier
        if expected_record_count != one_record_bytes {
            throw DBFError.READ_ERROR("Byte 10 in dbf file (number of bytes in one record) does not match total number of bytes accross all fields")
        }
        // lock column add
        self.dbfTable.lockColumnAdding()
        // terminator reached, read records
        current_byte += 1
//        current_byte += 2
        var collect: String = "" // for storing data we pick up
        var bytes_collect: [UInt8] = [] // for picking up data with type long/autoincrement
        var values_collected: [String] = [] // for storing our collected values
        var col_index: Int = 0 // for storing what index of the column we are at
        var record_deleted: Bool = false
        
        // make sure that the last byte is the eof marker
        if buffer[buffer.count - 1] != 0x1A {
            throw DBFError.READ_ERROR("EOF marker not found!")
        }
        
        while buffer[current_byte] != 0x1A {
            if values_collected.count == 0 && collect.count == 0 && buffer[current_byte] == 0x2A {
                // record deleted
                record_deleted = true
                current_byte += 1
            } else if values_collected.count == 0 && collect.count == 0 && buffer[current_byte] == 0x0020 {
                // record not deleted
                current_byte += 1
            } else if values_collected.count == 0 && collect.count == 0 {
                // strange character
                throw DBFError.READ_ERROR("Can't assert if the record is deleted")
            }
            // check if the col is of type long or autoincrement
            if self.dbfTable.getColumns()[col_index].columnType == .LONG || self.dbfTable.getColumns()[col_index].columnType == .AUTOINCREMENT {
                // the following was adapted from to convert [UInt8] to Int: https://stackoverflow.com/questions/32769929/convert-bytes-uint8-array-to-int-in-swift
                // we only have to record 4 bytes
                bytes_collect = [buffer[current_byte], buffer[current_byte + 1], buffer[current_byte + 2], buffer[current_byte + 3]]
                
                // shift byte count
                current_byte += 4
                // now convert to int
                let data_value: NSData = NSData(bytes: bytes_collect, length: 4)
                var data_v: UInt32 = 0
                data_value.getBytes(&data_v, length: 4)
//                data_v = UInt32(bigEndian: data_v)
                data_v = UInt32(data_v)
                collect = String(Int(data_v))
            } else if self.dbfTable.getColumns()[col_index].columnType == .DOUBLE {
                bytes_collect = [buffer[current_byte], buffer[current_byte + 1], buffer[current_byte + 2], buffer[current_byte + 3], buffer[current_byte + 4], buffer[current_byte + 5], buffer[current_byte + 6], buffer[current_byte + 7]]
                
                // the following was adapted from: https://stackoverflow.com/questions/31773367/convert-byte-array-to-double-in-swift
                
                // shift byte count
                current_byte += 8
                // now convert to double
                let d: Double = bytes_collect.withUnsafeBytes {
                    $0.load(fromByteOffset: 0, as: Double.self)
                }
                
                collect = String(d)
            } else {
                // collect values as we pick them up
                collect += String(UnicodeScalar(buffer[current_byte]))
                current_byte += 1
            }
            // check if collect has touched max length
            if collect.count == self.dbfTable.getColumns()[col_index].count || bytes_collect.count > 0 {
                // touched
                // clear bytes collect
                bytes_collect = []
                values_collected.append(collect)
                collect = ""
                col_index += 1
                // make sure col index is still valid
                if col_index >= self.dbfTable.getColumns().count {
                    // add row
                    try self.dbfTable.addRow(with: values_collected, deleted: record_deleted)
                    record_deleted = false // reset as necessary
                    // if we have reached the record count, break out of the loop
                    if self.dbfTable.getRows().count == rec {
                        break
                    }
                    col_index = 0 // reset col index
                    // expect eof marker
                    if current_byte >= buffer.count {
                        break
                    }
                    // reset values collected
                    values_collected = []
                }
            }
        }
        // we read all data by this point
    }
    /**
     * Reads a memo in a dbt file given the url. This already assumes that the dbf table has been generated (via the read function)
     * - Parameters:
     *  - file: Required. A URL to the DBT memo file. This **must** be in DBT format ONLY
     *  - index: Required. The index of the memo block derived from the value the record had
     * - Returns: A string representing the data the memo field held
     * - Throws: An error upon read
     * - Version: 1.0
     * - Since: 1.2
     * > Note: At the moment, only dBase III (version 3) DBT files are supported for reading
     */
    public func readMemo(file dbt: URL, index: Int) throws -> String {
        // get data first
        let buffer: Data = try Data(contentsOf: dbt)
        var memo: String = ""
        
        // make sure that the size of the dbt is at least 1024 bytes (512 bytes for the header and the next 512+ for the blocks)
        if buffer.count < 1024 {
            throw DBFError.READ_ERROR("DBT file is too small")
        }
        
        // lets also make sure the buffer is divisible by 512
        if buffer.count % 512 > 0 {
            throw DBFError.READ_ERROR("DBT file is not divisible by 512 (block size invalid). Please make sure each block size is exactly 512 bytes in size.")
        }
        
        // we can skip whatever is in the header, since that is irrelevant to the actual data being read
        
        let blockStart: Int = 512 * index
        
        // lets make sure that blockStart is in bounds
        if blockStart >= buffer.count {
            // get length of full dbt file
            let dbt_len: Int = buffer.count / 512
            throw DBFError.READ_ERROR("Index out of bounds! The DBT file has the highest index of \(dbt_len) and the index \(index) goes beyond this.")
        }
        
        // continue reading the data and converting the uint to string
        // add it to memo variable
        // and stop reading until the eof marker has been touched
        
        // lets find the eof marker
        let index_eof: Int = buffer.firstIndex(of: 0x1A) ?? buffer.count
        if index_eof == buffer.count {
            throw DBFError.READ_ERROR("Unterminated memo field! EOF marker not found")
        }
        
        // we should expect one more eof marker if the field appears to span over one block
        if blockStart + 512 < index_eof {
            if buffer[index_eof + 1] != 0x1A {
                throw DBFError.READ_ERROR("Unterminated memo field! EOF marker not found")
            }
        }
        
        // get all data from blockStart to index_eof
        let block: Data = buffer[blockStart..<index_eof]
        
        memo = String(decoding: block, as: Unicode.UTF8.self)
        
        return memo
    }
}
