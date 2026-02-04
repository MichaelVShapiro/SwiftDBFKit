//
//  DBFKitTests.swift
//  DBFKitTests
//
//  Created by Michael Shapiro on 4/29/24.
//

import XCTest
@testable import DBFKit

final class DBFKitTests: XCTestCase {

    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    /**
     * For testing writing to DBF
     */
    func testWriteDBF() {
        self.continueAfterFailure = false
        
        // make our dbf table
        let dbfTable: DBFTable = DBFTable()
        
        // add some random info
        do {
            try dbfTable.addColumn(with: "something", dataType: .STRING, count: 2)
            try dbfTable.addColumn(with: "anotherCol", dataType: .STRING, count: 4)
            dbfTable.lockColumnAdding()

            for _ in 0 ..< 512 {
              try dbfTable.addRow(with: ["gg", "gg"]) // we test for row adding when it matches up to full col length and when it doesn't
            }
            // init writer
            let writer: DBFWriter = DBFWriter(dbfTable: dbfTable)
            
            // write
            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbf")!)
            
            // we can now use our reader to confirm that the result succeeded
            let reader: DBFFile = DBFFile(path: Bundle(for: type(of: self)).path(forResource: "writeme", ofType: "dbf")!)
            try reader.read()

            XCTAssertEqual(512, reader.getNumRecords())
            XCTAssertEqual(512, reader.getDBFTable().getTotalRecordCount())
            XCTAssertTrue(reader.getDBFTable().getColumns().count == 2)
            XCTAssertTrue(reader.getDBFTable().getRows()[0][0] == "gg")
        } catch {
            print("\(error)")
            XCTAssertTrue(false)
        }
        
        // success
    }
    
    /**
     * Another test for writing DBF files
     */
    func testWriteDBF2() {
        self.continueAfterFailure = false
        
        let dbfTable: DBFTable = DBFTable()
        
        do {
            try dbfTable.addColumn(with: "something", dataType: .STRING, count: 2)
            try dbfTable.addColumn(with: "num", dataType: .NUMERIC, count: 1)
            try dbfTable.addColumn(with: "else", dataType: .STRING, count: 3)
            
            dbfTable.lockColumnAdding()
            
            try dbfTable.addRow(with: ["gg", "1", "gg"])
            try dbfTable.addRow(with: ["rg", "2", "rg"])
            try dbfTable.addRow(with: ["Å", "3", "ab"])

            let writer: DBFWriter = DBFWriter(dbfTable: dbfTable)
            
            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbf")!)
            
            let reader: DBFFile = DBFFile(path: Bundle(for: type(of: self)).path(forResource: "writeme", ofType: "dbf")!)
            
            try reader.read()
            
            XCTAssertTrue(reader.getDBFTable().getColumns().count == 3)
            XCTAssertTrue(reader.getNumRecords() == 3)
            XCTAssertEqual(reader.getDBFTable().getRows()[2][0], "Å")

        } catch {
            print("\(error)")
            XCTAssertTrue(false)
        }
    }
    /**
     * Tests writing memo files
     */
    func testWriteMemo() {
        self.continueAfterFailure = false
        
        let dbfTable: DBFTable = DBFTable()
        
        do {
            try dbfTable.addColumn(with: "something", dataType: .STRING, count: 2)
            try dbfTable.addColumn(with: "num", dataType: .NUMERIC, count: 1)
            try dbfTable.addColumn(with: "some_memo", dataType: .MEMO, count: DBFTable.MEMO_COUNT)
            
            dbfTable.lockColumnAdding()
            
            try dbfTable.addRow(with: ["a", "1", "test memo"])
            try dbfTable.addRow(with: ["b", "2", "test memo 2"])
            
            let writer: DBFWriter = DBFWriter(dbfTable: dbfTable)
            
            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbf")!)
            try writer.writeDBT(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbt")!)
            
            let reader: DBFFile = DBFFile(path: Bundle(for: type(of: self)).path(forResource: "writeme", ofType: "dbf")!)
            
            try reader.read()
            
            let db_table: DBFTable = reader.getDBFTable()
            
            XCTAssertTrue(db_table.getRows().count == 2)
            XCTAssertTrue(Int(db_table.getRows()[0][2]) != nil)
        } catch {
            print("\(error)")
            XCTAssertTrue(false)
        }
    }
    /**
     * Tests working with other data types such as long
     */
    func testOtherDataTypes() {
        self.continueAfterFailure = false
        
        var success: Bool = true
        
        do {
            let dbf_table: DBFTable = DBFTable()
            
            try dbf_table.addColumn(with: "test_num", dataType: .NUMERIC, count: 3)
            try dbf_table.addColumn(with: "test_float", dataType: .FLOAT, count: 4)
            try dbf_table.addColumn(with: "test_long", dataType: .LONG, count: DBFTable.LONG_COUNT)
            try dbf_table.addColumn(with: "test_memo", dataType: .MEMO, count: DBFTable.MEMO_COUNT)
            try dbf_table.addColumn(with: "test_double", dataType: .DOUBLE, count: DBFTable.DOUBLE_COUNT)
            
            dbf_table.lockColumnAdding()
            
            try dbf_table.addRow(with: ["1", "2.50", "20", "some memo...", "4.5"])
            try dbf_table.addRow(with: ["2", "3.5", "30", "another memo...", "5.5"])
            
            let writer: DBFWriter = DBFWriter(dbfTable: dbf_table)
            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbf")!)
            try writer.writeDBT(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbt")!)
            
            let reader: DBFFile = DBFFile(path: Bundle(for: type(of: self)).path(forResource: "writeme", ofType: "dbf")!)
            try reader.read()
            
            XCTAssertEqual(reader.getNumRecords(), 2)
            
            XCTAssertTrue(reader.getDBFTable().getRows()[0][2] == "20")
            XCTAssertTrue(reader.getDBFTable().getRows()[1][2] == "30")
            
            // for asserting doubles
            XCTAssertEqual(reader.getDBFTable().getRows()[0][4], "4.5")
        } catch {
            print("\(error)")
            success = false
        }
        
        XCTAssertTrue(success)
    }
    /**
     * This is really just to check the warnings DBFKit generates. So it should succeed no matter what
     */
    func testWarnings() {
        do {
            let dbf_table: DBFTable = DBFTable()
            try dbf_table.addColumn(with: "test", dataType: .BOOL, count: 2) // warning
            try dbf_table.addColumn(with: "test2", dataType: .STRING, count: 100) // no warning
            try dbf_table.addColumn(with: "test3", dataType: .MEMO, count: DBFTable.MEMO_COUNT) // no warning
        } catch {
            print("\(error)")
        }
    }
    /**
     * Tests to make sure timestamp is written properly
     */
    func testTimestamp() {
        self.continueAfterFailure = false
        var success: Bool = true
        do {
            let dbf_table: DBFTable = DBFTable()
            try dbf_table.addColumn(with: "test1", dataType: .STRING, count: 4)
            try dbf_table.addColumn(with: "test2", dataType: .TIMESTAMP, count: DBFTable.TIMESTAMP_COUNT)
            
            dbf_table.lockColumnAdding()
            
            var compp: DateComponents = DateComponents()
            compp.year = 2024
            compp.month = 12
            compp.day = 19
            compp.hour = 7
            compp.minute = 25
            compp.second = 6
            let d: Date = Calendar.current.date(from: compp)!
            
            try dbf_table.addRow(with: ["1234", DBFTable.convertToTimestamp(date: d)])
            
            let writer: DBFWriter = DBFWriter(dbfTable: dbf_table)
            
            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme", withExtension: "dbf")!)
            
            let reader: DBFFile = DBFFile(path: Bundle(for: type(of: self)).path(forResource: "writeme", ofType: "dbf")!)
            
            try reader.read()
            
            XCTAssertTrue(reader.getNumRecords() == 1)
            XCTAssertEqual(reader.getDBFTable().getRows()[0][1], dbf_table.getRows()[0][1])

            // now test convert out
            let date_check: Date = DBFTable.convertTimestampToDate(timestamp: reader.getDBFTable().getRows()[0][1])!
            
            let comp: DateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date_check)
            
            XCTAssertTrue(comp.year == 2024 && comp.month == 12 && comp.day == 19)
            XCTAssertTrue(comp.hour == 7 && comp.minute == 25 && comp.second == 6)
        } catch {
            print("\(error)")
            success = false
        }
        
        XCTAssertTrue(success)
    }
    
    /**
     * For testing to write dBase 7 level files
     */
    func testWriteDbase7() {
        self.continueAfterFailure = false
        var success: Bool = true
        
        // make dbf file
        let dbf_table: DBFTable = DBFTable()
        dbf_table.addColumn(DBFTable.DBFColumn(columnType: .AUTOINCREMENT, name: "TEST_AUTOINCREMENT", count: DBFTable.LONG_COUNT, next_autoincrement_value: 1))
        dbf_table.addColumn(DBFTable.DBFColumn(columnType: .STRING, name: "TEST_STRING", count: 20))
        
        dbf_table.lockColumnAdding()
        
        dbf_table.addRow(data: ["1", "some data"])
        dbf_table.addRow(data: ["2", "more data"])
        dbf_table.addRow(data: ["3", "deleted data"], is_deleted: true)
        
        dbf_table.incrementAutoIncrementValue(at: 0)
        dbf_table.incrementAutoIncrementValue(at: 0)
        dbf_table.incrementAutoIncrementValue(at: 0)
        
        do {
            let writer: DBFWriter = DBFWriter(dbfTable: dbf_table)
            
//            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, encoding: .utf8, version: .DBASE7)
            try writer.write(to: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, encoding: .utf8, version: .DBASE7)
        } catch {
            print("\(error)")
            success = false
        }
        
        XCTAssertTrue(success)
    }
    /**
     * Tests so we can read dbase7 level files
     * > Note: Make sure testWriteDbase7 is executed before running this function
     */
    func testReadDbase7() {
        self.continueAfterFailure = false
        var success: Bool = true
        
        do {
//            let file: DBFFile = DBFFile(contentsOf: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!)
            let file: DBFFile = DBFFile(contentsOf: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!)
            
            try file.readDbase7()
            
            // validate all data
            XCTAssertTrue(file.getDBFTable().getColumns()[0].next_autoincrement_value == 4)
            XCTAssertTrue(file.getDBFTable().getRows().count == 2)
            XCTAssertTrue(file.getDBFTable().getRows()[0][0] == "1")
            XCTAssertTrue(file.getDBFTable().getRows()[0][1] == "some data")
            XCTAssertTrue(file.getDBFTable().getRows()[1][0] == "2")
            XCTAssertTrue(file.getDBFTable().getRows()[1][1] == "more data")
            XCTAssertTrue(file.getDBFTable().getDeletedRows().count == 1)
            XCTAssertTrue(file.getDBFTable().getDeletedRows()[0][0] == "3")
            XCTAssertTrue(file.getDBFTable().getDeletedRows()[0][1] == "deleted data")
            XCTAssertTrue(file.getDBFTable().field_properties.dbfEncodingSize(version: .DBASE7) == 19)
        } catch {
            print("\(error)")
            success = false
        }
        
        XCTAssertTrue(success)
    }
    /**
     * All other test cases for working with dbase 7 level files
     */
    func testdBase7() {
        self.continueAfterFailure = false
        var success: Bool = true
        
        do {
            // these are just extra test cases to check up on
            
            //MARK: - DBF WITH NO DELETED RECORDS, "NORMAL" DBASE3 FIELDS
            let dbf_no_deleted: DBFTable = DBFTable()
            dbf_no_deleted.addColumn(DBFTable.DBFColumn(columnType: .NUMERIC, name: "TEST_NUMBER", count: 2))
            dbf_no_deleted.addColumn(DBFTable.DBFColumn(columnType: .BOOL, name: "TEST_BOOLEAN", count: DBFTable.BOOL_COUNT))
            dbf_no_deleted.addColumn(DBFTable.DBFColumn(columnType: .DATE, name: "TEST_DATE", count: DBFTable.DATE_COUNT))
            
            dbf_no_deleted.lockColumnAdding()
            
            dbf_no_deleted.addRow(data: ["10", "T", DBFTable.getDateValue(date: Date())])
            dbf_no_deleted.addRow(data: ["4", "?", DBFTable.getDateValue(date: Date())])
            
            let writer1: DBFWriter = DBFWriter(dbfTable: dbf_no_deleted)
            
            try writer1.write(to: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, version: .DBASE7)
            
            let reader1: DBFFile = try DBFFile(contentsOf: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, auto_read: true)
            
            XCTAssertTrue(reader1.getDBFTable().field_properties.dbfEncodingSize(version: .DBASE7) == 19)
            XCTAssertTrue(reader1.getDBFTable().getRows().count == 2)
            XCTAssertTrue(reader1.getDBFTable().getColumns().count == 3)
            XCTAssertTrue(reader1.getDBFTable().getRows()[0][0] == "10" && reader1.getDBFTable().getRows()[1][1] == "?")
            
            //MARK: - DBF WITH FIELD PROPERTIES
            //WARNING: THIS IS HIGHLY EXPERIMENTAL AND WITH LIMITED TEST CASES, THERE IS A CHANCE THE LOGIC OF HOW IT IS WRITTEN IS FLAWED!
            let dbf_with_properties: DBFTable = DBFTable()
            
            // add some properties
            dbf_with_properties.field_properties.standard_properties.append(FieldPropertiesStructure.StandardPropertyDescriptor(generational_number: 1, field_offset: 0, property: .REQUIRED, type: .CHAR, is_constraint: false, offset: 0, width: 1))
            dbf_with_properties.field_properties.referential_properties.append(FieldPropertiesStructure.ReferentialIntegrityDescriptor(is_master: false, sequential_num: 0, offset_rule_name: 0, size_prev_value: 0, offset_foreign: 0, size_prev_value_next: 0, should_update_cascase: false, num_fields_linking_key: 0, offset_local_table: 1, size_prev_value_next2: 0, offset_foreign_tag: 0, size_prev_value_next3: 0))
            
            // without a good testing harness, the above properties are most likely invalid
            // in fact, they probably are
            // we are just testing to make sure that at least everything is being written and read correctly
            
            dbf_with_properties.addColumn(DBFTable.DBFColumn(columnType: .STRING, name: "TEST_STRING_WITH_PROP", count: 10))
            dbf_with_properties.addColumn(DBFTable.DBFColumn(columnType: .NUMERIC, name: "TEST_NUMERIC_WITH_PROP", count: 4))
            
            let prop_encoding_size: Int = dbf_with_properties.field_properties.dbfEncodingSize(version: .DBASE7)
            
            dbf_with_properties.lockColumnAdding()
            
            dbf_with_properties.addRow(data: ["data", "2.1"])
            dbf_with_properties.addRow(data: ["more", "1"])
            
            let writer2: DBFWriter = DBFWriter(dbfTable: dbf_with_properties)
            try writer2.write(to: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, version: .DBASE7)
            
            // now read
            let reader2: DBFFile = try DBFFile(contentsOf: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, auto_read: true)
            
            XCTAssertTrue(reader2.getDBFTable().field_properties.dbfEncodingSize(version: .DBASE7) == prop_encoding_size) // just so this remains consistent
            XCTAssertTrue(reader2.getDBFTable().field_properties.standard_properties.count == 1 && reader2.getDBFTable().field_properties.standard_properties[0].type == .CHAR && reader2.getDBFTable().field_properties.standard_properties[0].field_offset == 0)
            XCTAssertTrue(
                reader2.getDBFTable().field_properties.referential_properties.count == 1
                &&
                reader2.getDBFTable().field_properties.referential_properties[0].offset_local_table == 1
            )
            XCTAssertTrue(
                reader2.getDBFTable().getRows().count == 2
                &&
                reader2.getDBFTable().getRows()[0][0] == "data"
                &&
                reader2.getDBFTable().getRows()[1][1] == "1"
            )
            
            //MARK: - MEMO TEST (CUSTOM BLOCK SIZE)
            let dbf_with_custom_block_size: DBFTable = DBFTable()
            dbf_with_custom_block_size.addColumn(DBFTable.DBFColumn(columnType: .AUTOINCREMENT, name: "id", count: DBFTable.LONG_COUNT, next_autoincrement_value: 1))
            dbf_with_custom_block_size.addColumn(DBFTable.DBFColumn(columnType: .STRING, name: "TEST_STR", count: 30))
            dbf_with_custom_block_size.addColumn(DBFTable.DBFColumn(columnType: .MEMO, name: "TEST_MEMO", count: DBFTable.MEMO_COUNT))
            
            dbf_with_custom_block_size.incrementAutoIncrementValue(at: 0)
            dbf_with_custom_block_size.incrementAutoIncrementValue(at: 0)
            
            dbf_with_custom_block_size.lockColumnAdding()
            
            dbf_with_custom_block_size.addRow(data: ["1", "simple data", "this will be stored in a dbt file"])
            dbf_with_custom_block_size.addRow(data: ["2", "more data", "example of something else that will be stored in a dbt"])
            
            let writer3: DBFWriter = DBFWriter(dbfTable: dbf_with_custom_block_size)
            
            // set custom block size
            writer3.dbt_block_size = 2 // one block is 1024 bytes
            try writer3.write(to: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, version: .DBASE7)
            try writer3.writeDBT(to: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbt")!)
            
            let reader3: DBFFile = try DBFFile(contentsOf: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbf")!, auto_read: true)
            XCTAssertTrue(
                reader3.getDBFTable().getRows().count == 2
                &&
                reader3.getDBFTable().getRows()[0][0] == "1"
                &&
                reader3.getDBFTable().getRows()[0][1] == "simple data"
                &&
                reader3.getDBFTable().getColumns()[0].next_autoincrement_value == 3
            )
            
            // read header data
            let dbt_header: DBFFile.DBTFileData = try reader3.getDbtHeaderData(file: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbt")!, version: .DBASE7)
            XCTAssertTrue(dbt_header.block_size == 2)
            
            // open dbt
            let dbt: Dictionary<Int, String> = try reader3.getDbtBlocks(file: Bundle(for: type(of: self)).url(forResource: "writeme_dbase7", withExtension: "dbt")!, block_size: dbt_header.block_size)
            XCTAssertTrue(
                dbt.keys.count == 3
                &&
                dbt[1] != nil && dbt[2] != nil
                &&
                dbt[1] == "this will be stored in a dbt file"
                &&
                dbt[2] == "example of something else that will be stored in a dbt"
            )
        } catch {
            print("\(error)")
            success = false
        }
        
        XCTAssertTrue(success)
    }
}
