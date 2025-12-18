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
}
