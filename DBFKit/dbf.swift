//
//  dbf.swift
//  DBFKit
//
//  Created by Michael Shapiro on 4/29/24.
//

import Foundation
import OSLog

/**
 * Just so we can validate column info better
 */
extension String {
    
    /**
     * Determines if the string contains only alphanumerical and underscore characters
     */
    func containsOnlyAlphaNumericsAndUnderscores() -> Bool {
        // make a character set of allowed chars
        var allowed_chars: CharacterSet = .alphanumerics
        
        // include "_"
        allowed_chars.insert("_")
        
        // now check if the string contains any chars not in the set
        let range_of_invalid_chars: Range<Index>? = self.rangeOfCharacter(from: allowed_chars.inverted)
        
        return range_of_invalid_chars == nil
    }
}

/**
 * Represents anything that can be encoded and decoded in DBF
 * - Version: 1.0
 * - Since: 1.4
 * > Note: This is experimental at the moment and may replace some properties in future releases
 */
protocol DBFCodable {
    
    /**
     * Encodes the object into something DBFKit can work with
     * - Parameters:
     *  - version: Required. The dbase version this is being run under
     * - Returns: The encoded data
     * - Version: 1.0
     * - Since: 1.4
     */
    func encodeToDBF(version: DbaseVersion) throws -> Data
    /**
     * Decodes the dbf data into a real value
     * - Parameters:
     *  - data: Required. The data to be decoded
     *  - version: Required. The dbase version this is being decoded under
     * - Returns: The decoded object
     * - Version: 1.0
     * - Since: 1.4
     */
    static func decodeDBF(from data: Data, version: DbaseVersion) throws -> Self
    /**
     * Gets the size of the (expected) encoding
     * - Parameters:
     *  - version: Required. The dbase version this is being decoded under
     * - Returns: The number of bytes the encoding takes up
     * - Version: 1.0
     * - Since: 1.4
     */
    func dbfEncodingSize(version: DbaseVersion) -> Int
}

/**
 * For managing DBF errors
 * - Version: 1.0
 * - Since: 1.0
 */
enum DBFError: Error {
    case COLUMN_ADD_ERR(String), ROW_ADD_ERR(String), READ_ERROR(String), WRITE_ERROR(String)
}

/**
 * The dBase version being used for the dbf file reading/writing
 * - Version: 1.0
 * - Since: 1.4
 * > Note: Most of these versions can be found: https://www.loc.gov/preservation/digital/formats/fdd/fdd000325.shtml#:~:text=A%20proprietary%20format%2C%20with%20only,Earlier%20versions%20are%20documented%20unofficially.&text=Data%20File%20Header%20Structure%20for,Description%20and%20DBase%20File%20Structure.&text=The%20DBF%20file%20format%20was,0xFB%20FoxBASE
 */
enum DbaseVersion: UInt8 {
    /// dBase version 3. This also represents dBase 4 and 5
    case DBASE3 = 0x03
    /// dBase version 7
    case DBASE7 = 0x04
    /// dBase version 3 with a dbt (memo) file
    case DBASE3_WITH_DBT = 0x83
    /// FoxBASE
    case FOX_BASE = 0x02
    /// Visual FoxPro
    case VISUAL_FOX_PRO = 0x30
    /// Visual FoxPro with Autoincrement enabled
    case VISUAL_FOX_PRO_AI_ENABLED = 0x31
    /// Visual FoxPro with field type Varchar or Varbinary
    case VISUAL_FOX_PRO_WITH_VAR = 0x32
    /// dBase version 4 SQL table file with no memo
    case DBASE4_SQL_FILE_NO_MEMO = 0x43
    /// dBase version 4 SQL system file with no memo
    case DBASE4_SQL_SYSTEM_FILE_NO_MEMO = 0x63
    /// dBase version 4 with memo
    case DBASE4_WITH_MEMO = 0x8B
    /// dBase version 4 SQL table file with memo
    case DBASE4_SQL_FILE_WITH_MEMO = 0xCB
    /// FoxPro 2.x (or earlier) with memo
    case FOX_PRO_WITH_MEMO = 0xF5
    /// HiPer-Six format with SMT memo file
    case HIPER_SIX_WITH_MEMO = 0xE5
    /// FoxBASE - this for some weird reason is similar to FOX\_BASE?
    case FOXBASE = 0xFB
}

/**
 * The field properties structure schema. This is strictly unique to dBase 7
 * - Version: 1.0
 * - Since: 1.4
 * > Note: this is an experimental structure!
 */
class FieldPropertiesStructure: DBFCodable {
    
    /**
     * The field type
     * - Version: 1.0
     * - Since: 1.4
     */
    enum FieldType: UInt8 {
        case NO_TYPE = 0x00
        case CHAR = 0x01
        case NUMERIC = 0x02
        case MEMO = 0x03
        case LOGICAL = 0x04
        case DATE = 0x05
        case FLOAT = 0x06
        case OLE = 0x08
        case BINARY = 0x09
        case LONG = 0x11
        case TIMESTAMP = 0x12
        case DOUBLE = 0x13
        case AUTOINCREMENT = 0x14
    }
    
    /**
     * The standard property descriptor
     * - Version: 1.0
     * - Since: 1.4
     */
    struct StandardPropertyDescriptor: DBFCodable {
        
        /**
         * The field property being described
         * - Version: 1.0
         * - Since: 1.4
         */
        enum FieldProperty: UInt8 {
            case REQUIRED = 0x01
            case MIN = 0x02
            case MAX = 0x03
            case DEFAULT = 0x04
            case DATABASE_CONSTRAINT = 0x06
        }
        
        /// The generational number
        var generational_number: Int
        /// The field this descriptor is associated with
        /// This is represented by the index of the column in the dbf table
        var field_offset: Int
        /// The property being described
        var property: FieldProperty
        /// The type of field
        var type: FieldType
        /// If this field is a constraint
        var is_constraint: Bool
        /// Offset from the start of the structure. This is 0 if property == REQUIRED
        var offset: Int
        /// Width of the database field associated with this property
        var width: Int
        
        // for encoding to DBF
        func encodeToDBF(version: DbaseVersion) throws -> Data {
            // assert that the dbase version if 7
            if version != .DBASE7 {
                throw DBFError.WRITE_ERROR("FieldPropertiesStructure.StandardPropertyDescriptor is only valid for dBase 7")
            }
            // this will be exactly 15 bytes long
            var buffer: Data = Data(count: 15)
            
            // bytes 0-1 is the generational number
            // convert the generational number to two bytes of uint16
            let generational_bytes = [UInt8((self.generational_number.littleEndian >> 8) & 0x00FF), UInt8(self.generational_number.littleEndian & 0x00FF)]
            
            buffer[0] = generational_bytes[0]
            buffer[1] = generational_bytes[1]
            
            // bytes 2-3 is the offset
            let field_offset_bytes: [UInt8] = [UInt8((self.field_offset.littleEndian >> 8) & 0x00FF), UInt8(self.field_offset.littleEndian & 0x00FF)]
            
            buffer[2] = field_offset_bytes[0]
            buffer[3] = field_offset_bytes[1]
            
            // byte 4 is the property
            buffer[4] = self.property.rawValue
            
            // byte 5 is the field type
            buffer[5] = self.type.rawValue
            
            // byte 6 refers to if this is a constraint
            buffer[6] = self.is_constraint ? 0x00 : 0x02
            
            // bytes 7-10 are reserved
            // bytes 11-12 is the offset
            let offset_bytes: [UInt8] = [UInt8((self.offset.littleEndian >> 8) & 0x00FF), UInt8(self.offset.littleEndian & 0x00FF)]
            
            buffer[11] = offset_bytes[0]
            buffer[12] = offset_bytes[1]
            
            // last two bytes are the width
            let width_bytes: [UInt8] = [UInt8((self.width.littleEndian >> 8) & 0x00FF), UInt8(self.width.littleEndian & 0x00FF)]
            
            buffer[13] = width_bytes[0]
            buffer[14] = width_bytes[1]
            
            return buffer
        }
        // for decoding
        static func decodeDBF(from data: Data, version: DbaseVersion) throws -> FieldPropertiesStructure.StandardPropertyDescriptor {
            // assert we are in dbase7
            if version != .DBASE7 {
                throw DBFError.READ_ERROR("FieldPropertiesStructure.StandardPropertyDescriptor is only valid for dBase 7")
            }
            // first two bytes should be an int
//            let gen_num = Int(data.subdata(in: 0..<2).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let gen_num: Int = Int(UInt16(data[0]) << 8 | UInt16(data[1]))
            
            // next two are field offset
//            let f_offset = Int(data.subdata(in: 2..<4).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let f_offset = Int(UInt16(data[2]) << 8 | UInt16(data[3]))
            
            // byte 4 is property
            let prop: FieldProperty? = FieldProperty(rawValue: data[4])
            if prop == nil {
                throw DBFError.READ_ERROR("Unknown field property given: \(data[4])")
            }
            
            // byte 5 is field type
            let type: FieldType? = FieldType(rawValue: data[5])
            if type == nil {
                throw DBFError.READ_ERROR("Unknown field type given: \(data[5])")
            }
            
            // byte 6 is constraint
            let con_raw = data[6]
            if con_raw != 0x00 && con_raw != 0x02 {
                throw DBFError.READ_ERROR("Cannot assert if property is constrained as it is not 0x00 or 0x02: \(con_raw)")
            }
            let is_con = data[6] == 0x00
            
            // bytes 11-12 is the offset
//            let offset_struct = Int(data.subdata(in: 11..<13).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let offset_struct: Int = Int(UInt16(data[11]) << 8 | UInt16(data[12]))
            
            // last two bytes are width
//            let width_struct = Int(data.subdata(in: 13..<15).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let width_struct: Int = Int(UInt16(data[13]) << 8 | UInt16(data[14]))
            
            return StandardPropertyDescriptor(
                generational_number: gen_num,
                field_offset: f_offset,
                property: prop!,
                type: type!,
                is_constraint: is_con,
                offset: offset_struct,
                width: width_struct
            )
        }
        // the size
        func dbfEncodingSize(version: DbaseVersion) -> Int {
            return 15 // will always be this -- we don't even need to check version
        }
    }
    
    /**
     * A custom property descriptor
     */
    struct CustomPropertyDescriptor: DBFCodable {
        
        /// The generational number
        var generational_number: Int
        /// The field this descriptor is associated with
        /// This is represented by the index of the column in the dbf table
        var field_offset: Int
        /// The field type
        var type: FieldType
        /// Offset from start of structure to property name
        var offset: Int
        /// Length of the custom property name
        var len: Int
        /// Offset to the data
        var offset_data: Int
        /// Length to the custom property data
        var len_data: Int
        
        // for encoding
        func encodeToDBF(version: DbaseVersion) throws -> Data {
            // we only support dbase7 for this
            if version != .DBASE7 {
                throw DBFError.WRITE_ERROR("FieldPropertiesStructure.CustomPropertyDescriptor: Only dBase 7 is supported for custom properties")
            }
            // initialize buffer with 14 bytes
            var buffer: Data = Data(count: 14)
            
            // bytes 0-3 are made the same way as the standard property
            // convert the generational number to two bytes of uint16
            let generational_bytes = [UInt8((self.generational_number.littleEndian >> 8) & 0x00FF), UInt8(self.generational_number.littleEndian & 0x00FF)]
            
            buffer[0] = generational_bytes[0]
            buffer[1] = generational_bytes[1]
            
            // bytes 2-3 is the offset
            let field_offset_bytes: [UInt8] = [UInt8((self.field_offset.littleEndian >> 8) & 0x00FF), UInt8(self.field_offset.littleEndian & 0x00FF)]
            
            buffer[2] = field_offset_bytes[0]
            buffer[3] = field_offset_bytes[1]
            
            // byte 4 is type
            buffer[4] = self.type.rawValue
            
            // byte 5 is reserved
            
            // bytes 6-7 is offset
            let offset_bytes: [UInt8] = [UInt8((self.offset.littleEndian >> 8) & 0x00FF), UInt8(self.offset.littleEndian & 0x00FF)]
            
            buffer[6] = offset_bytes[0]
            buffer[7] = offset_bytes[1]
            
            // bytes 8-9 is length of custom property name
            let len_bytes: [UInt8] = [UInt8((self.len.littleEndian >> 8) & 0x00FF), UInt8(self.len.littleEndian & 0x00FF)]
            
            buffer[8] = len_bytes[0]
            buffer[9] = len_bytes[1]
            
            // bytes 10-11 is offset to the data
            let offset_data_bytes: [UInt8] = [UInt8((self.offset_data.littleEndian >> 8) & 0x00FF), UInt8(self.offset_data.littleEndian & 0x00FF)]
            
            buffer[10] = offset_data_bytes[0]
            buffer[11] = offset_data_bytes[1]
            
            // bytes 12-13 are length of custom property data
            let len_data_bytes: [UInt8] = [UInt8((self.len_data.littleEndian >> 8) & 0x00FF), UInt8(self.len_data.littleEndian & 0x00FF)]
            
            buffer[12] = len_data_bytes[0]
            buffer[13] = len_data_bytes[1]
            
            return buffer
        }
        // for decoding
        static func decodeDBF(from data: Data, version: DbaseVersion) throws -> FieldPropertiesStructure.CustomPropertyDescriptor {
            // verify version
            if version != .DBASE7 {
                throw DBFError.READ_ERROR("FieldPropertiesStructure.CustomPropertyDescriptor is only supported for DBase 7")
            }
            // decoding first few bytes is similar to the standard property descriptor
//            let gen_num = Int(data.subdata(in: 0..<2).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let gen_num: Int = FieldPropertiesStructure.convertFromBytes16(data[0], data[1])
            
            // next two are field offset
//            let f_offset = Int(data.subdata(in: 2..<4).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let f_offset: Int = FieldPropertiesStructure.convertFromBytes16(data[2], data[3])
            
            // byte 4 is field type
            let f_type: FieldType? = FieldType(rawValue: data[4])
            if f_type == nil {
                throw DBFError.READ_ERROR("Unknown field type given: \(data[4])")
            }
            
            // byte 5 is reserved
            
            // bytes 6-7
//            let offset_name = Int(data.subdata(in: 6..<8).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let offset_name: Int = FieldPropertiesStructure.convertFromBytes16(data[6], data[7])
            
            // bytes 8-9
//            let len_name = Int(data.subdata(in: 8..<10).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let len_name: Int = FieldPropertiesStructure.convertFromBytes16(data[8], data[9])
            
            // bytes 10-11
//            let offset_data = Int(data.subdata(in: 10..<12).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let offset_data: Int = FieldPropertiesStructure.convertFromBytes16(data[10], data[11])
            
            // bytes 12-13
//            let len_data = Int(data.subdata(in: 12..<14).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let len_data: Int = FieldPropertiesStructure.convertFromBytes16(data[12], data[13])
            
            // put it together
            return CustomPropertyDescriptor(
                generational_number: gen_num,
                field_offset: f_offset,
                type: f_type!,
                offset: offset_name,
                len: len_name,
                offset_data: offset_data,
                len_data: len_data
            )
        }
        // for getting size of encoding
        func dbfEncodingSize(version: DbaseVersion) -> Int {
            return 14 // will always be 14 bytes -- we don't even need to check the version
        }
    }
    
    /**
     * Referential integrity descriptor
     * - Version: 1.0
     * - Since: 1.4
     */
    struct ReferentialIntegrityDescriptor: DBFCodable {
        
        /// If this is the master (parent) or dependent (child)
        var is_master: Bool
        /// The sequential number, 1 based counting. If this number is 0, the referential integrity has been dropped
        var sequential_num: Int
        /// Offset of this rule name
        var offset_rule_name: Int
        /// Size of the previous value
        var size_prev_value: Int
        /// The offset of the name in the foreign table
        var offset_foreign: Int
        /// Size of previous value (bytes 9-10)
        var size_prev_value_next: Int
        /// If this should be update cascase or delete cascade
        var should_update_cascase: Bool
        /// Number of fields in the linking key
        var num_fields_linking_key: Int
        /// Offset of local table
        var offset_local_table: Int
        /// Size of previous value (bytes 16-17)
        var size_prev_value_next2: Int
        /// Offset of foreign table tag
        var offset_foreign_tag: Int
        /// Size of previous value (bytes 20-21)
        var size_prev_value_next3: Int
        
        // for encoding
        func encodeToDBF(version: DbaseVersion) throws -> Data {
            // verify version
            if version != .DBASE7 {
                throw DBFError.WRITE_ERROR("FieldPropertiesStructure.ReferentialIntegrityDescriptor only works for dBase 7")
            }
            // initialize buffer with 22 bytes
            var buffer: Data = Data(count: 22)
            
            // bytes 0 is if this is the master
            buffer[0] = self.is_master ? 0x07 : 0x08
            
            // bytes 1-2 is sequential number
            let seq_bytes: [UInt8] = [UInt8((self.sequential_num.littleEndian >> 8) & 0x00FF), UInt8(self.sequential_num.littleEndian & 0x00FF)]
            buffer[1] = seq_bytes[0]
            buffer[2] = seq_bytes[1]
            
            // bytes 3-4 offset of ri rule name
            let ri_rule: [UInt8] = [UInt8((self.offset_rule_name.littleEndian >> 8) & 0x00FF), UInt8(self.offset_rule_name.littleEndian & 0x00FF)]
            buffer[3] = ri_rule[0]
            buffer[4] = ri_rule[1]
            
            // bytes 5-6 size of previous value
            let prev1: [UInt8] = [UInt8((self.size_prev_value.littleEndian >> 8) & 0x00FF), UInt8(self.size_prev_value.littleEndian & 0x00FF)]
            buffer[5] = prev1[0]
            buffer[6] = prev1[1]
            
            // bytes 7-8 offset of name in foreign table
            let offset_name_bytes: [UInt8] = [UInt8((self.offset_foreign.littleEndian >> 8) & 0x00FF), UInt8(self.offset_foreign.littleEndian & 0x00FF)]
            buffer[7] = offset_name_bytes[0]
            buffer[8] = offset_name_bytes[1]
            
            // bytes 9-10 size of previous value
            let prev2: [UInt8] = [UInt8((self.size_prev_value_next.littleEndian >> 8) & 0x00FF), UInt8(self.size_prev_value_next.littleEndian & 0x00FF)]
            buffer[9] = prev2[0]
            buffer[10] = prev2[1]
            
            // byte 11 update and delete behavior
            buffer[11] = self.should_update_cascase ? 0x10 : 0x01
            
            // bytes 12-13 num fields in linking key
            let num_linking: [UInt8] = [UInt8((self.num_fields_linking_key.littleEndian >> 8) & 0x00FF), UInt8(self.num_fields_linking_key.littleEndian & 0x00FF)]
            buffer[12] = num_linking[0]
            buffer[13] = num_linking[1]
            
            // bytes 14-15 offset local table
            let offset_local_bytes: [UInt8] = [UInt8((self.offset_local_table.littleEndian >> 8) & 0x00FF), UInt8(self.offset_local_table.littleEndian & 0x00FF)]
            buffer[14] = offset_local_bytes[0]
            buffer[15] = offset_local_bytes[1]
            
            // bytes 16-17 size of previous value
            let prev3: [UInt8] = [UInt8((self.size_prev_value_next2.littleEndian >> 8) & 0x00FF), UInt8(self.size_prev_value_next2.littleEndian & 0x00FF)]
            buffer[16] = prev3[0]
            buffer[17] = prev3[1]
            
            // bytes 18-19 offset foreign table tag name
            let offset_tag_bytes: [UInt8] = [UInt8((self.offset_foreign_tag.littleEndian >> 8) & 0x00FF), UInt8(self.offset_foreign_tag.littleEndian & 0x00FF)]
            buffer[18] = offset_tag_bytes[0]
            buffer[19] = offset_tag_bytes[1]
            
            // bytes 20-21 size of previous values
            let prev4: [UInt8] = [UInt8((self.size_prev_value_next3.littleEndian >> 8) & 0x00FF), UInt8(self.size_prev_value_next3.littleEndian & 0x00FF)]
            buffer[20] = prev4[0]
            buffer[21] = prev4[1]
            
            return buffer
        }
        // for decoding
        static func decodeDBF(from data: Data, version: DbaseVersion) throws -> FieldPropertiesStructure.ReferentialIntegrityDescriptor {
            // verify version
            if version != .DBASE7 {
                throw DBFError.READ_ERROR("FieldPropertiesStructure.ReferentialIntegrityDescriptor is only valid in Dbase 7")
            }
            // validate length
            if data.count != 22 {
                throw DBFError.READ_ERROR("A referential integrity descriptor must be 22 bytes in length but what was given is: \(data.count)")
            }
            // byte 0 determines if this is master or dependent
            if data[0] != 0x07 && data[0] != 0x08 {
                throw DBFError.READ_ERROR("Couldn't determine if referential integrity is master or dependent: \(data[0])")
            }
            let is_master = data[0] == 0x07
            
            // bytes 1-2 is sequential number
//            let seq_num = Int(data.subdata(in: 1..<3).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let seq_num: Int = FieldPropertiesStructure.convertFromBytes16(data[1], data[2])
            
            // bytes 3-4 offset of ri rule name
//            let offset_ri = Int(data.subdata(in: 3..<5).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let offset_ri: Int = FieldPropertiesStructure.convertFromBytes16(data[3], data[4])
            
            // bytes 5-6 size of previous value
//            let size1 = Int(data.subdata(in: 5..<7).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let size1: Int = FieldPropertiesStructure.convertFromBytes16(data[5], data[6])
            
            // bytes 7-8 offset of name in foreign table
//            let offset_foreign_name = Int(data.subdata(in: 7..<9).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let offset_foreign_name: Int = FieldPropertiesStructure.convertFromBytes16(data[7], data[8])
            
            // bytes 9-10 size of previous value
//            let size2 = Int(data.subdata(in: 9..<11).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let size2: Int = FieldPropertiesStructure.convertFromBytes16(data[9], data[10])
            
            // byte 11 is update and delete behavior
            // validate the correctness of this
            if data[11] != 0x10 && data[11] != 0x01 {
                throw DBFError.READ_ERROR("Couldn't determine if referential integrity is update-cascade or not: \(data[11])")
            }
            let should_update_cascade = data[11] == 0x10
            
            // bytes 12-13 is number of fields in linking key
//            let num_fields_linking_key = Int(data.subdata(in: 12..<14).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let num_fields_linking_key: Int = FieldPropertiesStructure.convertFromBytes16(data[12], data[13])
            
            // bytes 14-15 offset of local table tag name
//            let local_table_tag_name = Int(data.subdata(in: 14..<16).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let local_table_tag_name: Int = FieldPropertiesStructure.convertFromBytes16(data[14], data[15])
            
            // bytes 16-17 size of previous value
//            let size3 = Int(data.subdata(in: 16..<18).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let size3: Int = FieldPropertiesStructure.convertFromBytes16(data[16], data[17])
            
            // bytes 18-19 offset of foreign table tag name
//            let offset_tag_name = Int(data.subdata(in: 18..<19).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let offset_tag_name: Int = FieldPropertiesStructure.convertFromBytes16(data[18], data[19])
            
            // bytes 20-21 size of previous value
//            let size4 = Int(data.subdata(in: 20..<21).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//                return pointer.load(as: UInt32.self).littleEndian
//            })
            let size4: Int = FieldPropertiesStructure.convertFromBytes16(data[20], data[21])
            
            return ReferentialIntegrityDescriptor(
                is_master: is_master,
                sequential_num: seq_num,
                offset_rule_name: offset_ri,
                size_prev_value: size1,
                offset_foreign: offset_foreign_name,
                size_prev_value_next: size2,
                should_update_cascase: should_update_cascade,
                num_fields_linking_key: num_fields_linking_key,
                offset_local_table: local_table_tag_name,
                size_prev_value_next2: size3,
                offset_foreign_tag: offset_tag_name,
                size_prev_value_next3: size4
            )
        }
        // encoding size
        func dbfEncodingSize(version: DbaseVersion) -> Int {
            return 22 // will always be 22
        }
    }
    
    /**
     * All standard properties
     * - Version: 1.0
     * - Since: 1.4
     */
    var standard_properties: [StandardPropertyDescriptor] = []
    /**
     * All custom properties
     * - Version: 1.0
     * - Since: 1.4
     */
    var custom_properties: [CustomPropertyDescriptor] = []
    /**
     * All refernential integrity properties
     * - Version: 1.0
     * - Since: 1.4
     */
    var referential_properties: [ReferentialIntegrityDescriptor] = []
    /**
     * Start of standard properties
     * - Version: 1.0
     * - Since: 1.4
     */
    var start_standard_properties: UInt16 = 0
    /**
     * Start of custom properties
     * - Version: 1.0
     * - Since: 1.4
     */
    var start_custom_properties: UInt16 = 0
    /**
     * Start of referential properties
     * - Version: 1.0
     * - Since: 1.4
     */
    var start_referential_properties: UInt16 = 0
    /**
     * Start of data
     * - Version: 1.0
     * - Since: 1.4
     */
    var start_of_data: UInt16 = 0
    /**
     * Actual size of structure including data
     * - Version: 1.0
     * - Since: 1.4
     */
    var actual_size: UInt16 = 0
    
    /**
     * For getting the bytes to be stored for standard property size
     * - Version: 1.0
     * - Since: 1.4
     */
    var standard_properties_count: [UInt8] {
        return [UInt8((self.standard_properties.count.littleEndian >> 8) & 0x00FF), UInt8(self.standard_properties.count.littleEndian & 0x00FF)]
    }
    /**
     * For getting the bytes to be stored for custom property size
     * - Version: 1.0
     * - Since: 1.4
     */
    var custom_properties_count: [UInt8] {
        return [UInt8((self.custom_properties.count.littleEndian >> 8) & 0x00FF), UInt8(self.custom_properties.count.littleEndian & 0x00FF)]
    }
    /**
     * For getting the bytes to be stored for referential property size
     * - Version: 1.0
     * - Since: 1.4
     */
    var referential_properties_count: [UInt8] {
        return [UInt8((self.referential_properties.count.littleEndian >> 8) & 0x00FF), UInt8(self.referential_properties.count.littleEndian & 0x00FF)]
    }
    
    /**
     * Just a helper function for converting to bytes into a int
     * - Version: 1.0
     * - Since: 1.4
     * - Parameters:
     *  - d1: Required. The first byte
     *  - d2: Required. The second byte
     * - Returns: The int
     */
    public static func convertFromBytes(_ d1: UInt8, _ d2: UInt8) -> Int {
        return Int(Data([d1, d2]).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            return pointer.load(as: UInt32.self).littleEndian
        })
    }
    /**
     * Just a helper function for converting to bytes (uint16) into a int
     * - Version: 1.0
     * - Since: 1.4
     * - Parameters:
     *  - d1: Required. The first byte
     *  - d2: Required. The second byte
     * - Returns: The int
     */
    public static func convertFromBytes16(_ d1: UInt8, _ d2: UInt8) -> Int {
//        return Int(Data([d1, d2]).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
//            return pointer.load(as: UInt16.self).littleEndian
//        })
        return Int(UInt16(d1) << 8 | UInt16(d2))
    }
    
    // for encoding
    func encodeToDBF(version: DbaseVersion) throws -> Data {
        // this is only supported in dbase7
        if version != .DBASE7 {
            throw DBFError.WRITE_ERROR("FieldPropertiesStructure is only supported in dbase7")
        }
        // reserve 16 bytes for now
        var buffer: Data = Data(count: 16)
        
        // bytes 0-1 is number of standard properties
        buffer[0] = self.standard_properties_count[0]
        buffer[1] = self.standard_properties_count[1]
        
        // bytes 2-3 is start of descriptor for standard property
        // we store in litle endian format
        buffer[2] = UInt8(self.start_standard_properties & 0x00FF)
        buffer[3] = UInt8(self.start_standard_properties >> 8)
        
        // bytes 4-5 is number of custom properties
        buffer[4] = self.custom_properties_count[0]
        buffer[5] = self.custom_properties_count[1]
        
        // bytes 6-7 is start of custom descriptor
        buffer[6] = UInt8(self.start_custom_properties & 0x00FF)
        buffer[7] = UInt8(self.start_custom_properties >> 8)
        
        // bytes 8-9 is number of referential properties
        buffer[8] = self.referential_properties_count[0]
        buffer[9] = self.referential_properties_count[1]
        
        // bytes 10-11 is start of referential descriptor
        buffer[10] = UInt8(self.start_referential_properties & 0x00FF)
        buffer[11] = UInt8(self.start_referential_properties >> 8)
        
        // bytes 12-13 is start of data
        buffer[12] = UInt8(self.start_of_data & 0x00FF)
        buffer[13] = UInt8(self.start_of_data >> 8)
        
        // bytes 14-15 is size of structure
        buffer[14] = UInt8(self.actual_size & 0x00FF)
        buffer[15] = UInt8(self.actual_size >> 8)
        
        // starting byte 16 we input all standard properties
        for property in self.standard_properties {
            let property_data: Data = try property.encodeToDBF(version: version)
            buffer.append(property_data)
        }
        
        // if we have no standard property structures, just fill in 0 for that byte
        if self.standard_properties.isEmpty {
            buffer.append(Data(count: 1))
        }
        
        // next we put in all custom properties
        for property in self.custom_properties {
            let property_data: Data = try property.encodeToDBF(version: version)
            buffer.append(property_data)
        }
        
        // if we have now custom properties just fill in 0 for that byte
        if self.custom_properties.isEmpty {
            buffer.append(Data(count: 1))
        }
        
        // finally we put in the referential properties
        for property in self.referential_properties {
            let property_data: Data = try property.encodeToDBF(version: version)
            buffer.append(property_data)
        }
        
        // if we have no referential properties just fill in 0 for that byte
        if self.referential_properties.isEmpty {
            buffer.append(Data(count: 1))
        }
        
        // done
        return buffer
    }
    // for decoding
    static func decodeDBF(from data: Data, version: DbaseVersion) throws -> Self {
        // verify this is dbase 7 only
        if version != .DBASE7 {
            throw DBFError.READ_ERROR("FieldPropertiesStructure is only for dbase 7")
        }
        // we need at least 16 bytes
        if data.count < 16 {
            throw DBFError.READ_ERROR("Field properties structure is too small")
        }
        // bytes 0-1 is num standard properties
        let num_standard: Int = self.convertFromBytes16(data[0], data[1])
        
        // we don't really care about the start, more so the number of each descriptor
        let num_custom: Int = self.convertFromBytes16(data[4], data[5])
        let num_referential: Int = self.convertFromBytes16(data[8], data[9])
        
        // start at byte 16 and begin to read the data
        var current_byte: Int = 16
        var standard_properties: [FieldPropertiesStructure.StandardPropertyDescriptor] = []
        for _ in 0..<num_standard {
            // one of these is 15 bytes in size
            // so get the block
            let ending: Int = current_byte + 15
            let block: Data = data.subdata(in: current_byte..<ending)
            standard_properties.append(try FieldPropertiesStructure.StandardPropertyDescriptor.decodeDBF(from: block, version: version))
            
            // increment current bytes to the start of the next block
            current_byte = ending + 0
        }
        
        // if there were no standard properties, shift the byte
        if num_standard == 0 {
            // just assert that the current byte is 0
            guard data[current_byte] == 0 else {
                throw DBFError.READ_ERROR("Unexpected byte found for standard property descriptor: \(data[current_byte])")
            }
            current_byte += 1
        }
        
        var custom_prop: [FieldPropertiesStructure.CustomPropertyDescriptor] = []
        // now get custom properties
        for _ in 0..<num_custom {
            // one of these is 14 bytes in size
            // so get the block
            let ending: Int = current_byte + 14
            let block: Data = data.subdata(in: current_byte..<ending)
            custom_prop.append(try FieldPropertiesStructure.CustomPropertyDescriptor.decodeDBF(from: block, version: version))
            
            // increment current bytes to the start of the next block
            current_byte = ending + 0
        }
        
        // do same check with custom property
        if num_custom == 0 {
            guard data[current_byte] == 0 else {
                throw DBFError.READ_ERROR("Unexpected byte found for custom property descriptor: \(data[current_byte])")
            }
            current_byte += 1
        }
        
        // finally get referential properties
        var ref_prop: [FieldPropertiesStructure.ReferentialIntegrityDescriptor] = []
        for _ in 0..<num_referential {
            // one of these is 22 bytes in size
            // so get the block
            let ending: Int = current_byte + 22
            let block: Data = data.subdata(in: current_byte..<ending)
            ref_prop.append(try FieldPropertiesStructure.ReferentialIntegrityDescriptor.decodeDBF(from: block, version: version))
            
            // increment current bytes to the start of the next block
            current_byte = ending + 0
        }
        
        // do same check for referential integiry
        if num_referential == 0 {
            guard data[current_byte] == 0 else {
                throw DBFError.READ_ERROR("Unexpected byte found for custom property descriptor: \(data[current_byte])")
            }
            current_byte += 1
        }
        
        // done
        let con: FieldPropertiesStructure = FieldPropertiesStructure()
        con.standard_properties = standard_properties
        con.custom_properties = custom_prop
        con.referential_properties = ref_prop
        con.start_standard_properties = data.subdata(in: 2..<4).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            return pointer.load(as: UInt16.self).littleEndian
        }
        con.start_custom_properties = data.subdata(in: 6..<8).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            return pointer.load(as: UInt16.self).littleEndian
        }
        con.start_referential_properties = data.subdata(in: 10..<12).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            return pointer.load(as: UInt16.self).littleEndian
        }
        con.start_of_data = data.subdata(in: 12..<14).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            return pointer.load(as: UInt16.self).littleEndian
        }
        con.actual_size = data.subdata(in: 14..<16).withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            return pointer.load(as: UInt16.self).littleEndian
        }
        
        return con as! Self
    }
    // for getting encoding size
    func dbfEncodingSize(version: DbaseVersion) -> Int {
        // first part of structure is 16 bytes
        let fixed_part_size: Int = 16
        
        // each standard property is 15 bytes
        var standard_property_size: Int = 15 * self.standard_properties.count
        
        // if we have no standard properties, the size will be 1
        if self.standard_properties.isEmpty {
            standard_property_size = 1
        }
        
        // each custom property is 14 bytes
        var custom_property_size: Int = 14 * self.custom_properties.count
        
        // if we have no custom properties, the size will be 1
        if self.custom_properties.isEmpty {
            custom_property_size = 1
        }
        
        // each referential property is 22 bytes
        var referential_property_size: Int = 22 * self.referential_properties.count
        
        // if we have no referential properties, the size will be 1
        if self.referential_properties.isEmpty {
            referential_property_size = 1
        }
        
        return fixed_part_size + standard_property_size + custom_property_size + referential_property_size
    }
}

/**
 * A DBF table which stores all the data
 * - Version: 1.3
 * - Since: 1.0
 */
class DBFTable {
    
    /**
     * A column data type
     * - Version: 1.2
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
        /// Represents the column of type long. It really just stores an integer
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
        /// Represents the column of type timestamp
        /// - Version: 1.0
        /// - Since: 1.3
        /// > Note: This data type holds two values, the actual date (which is the number of days since January 1 4713 BC) and the time. When writing to this field, to represent the data accurately, call DBFTable.convertToTimestamp to create a string representation of the data
        case TIMESTAMP = "@"
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
        /**
         * The next autoincrement value. This is strictly only supported in dBase7. Defaults to nil
         * - Version: 1.0
         * - Since: 1.4
         */
        var next_autoincrement_value: Int? = nil
        /**
         * If the field has a tag in a production .MDX file
         * - Version: 1.0
         * - Since: 1.4
         */
        var has_index_in_mdx_file: Bool? = false
        /**
         * How many decimal points are after the actual decimal in numeric values
         * - Version: 1.0
         * - Since: 1.4
         * > Note: This only applies to numeric fields like NUMERIC and FLOAT. It just says how many values are expected after the decimal point. For example, if we have a number like 3.14, this is represented as N(4, 2) where 4 is the length of the field (this is '3' '.' '1' '4' that is 4 total) and 2 represented 2 values after the decimal point
         */
        var decimal_count: Int? = 0
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
     * The field properties
     * - Version: 1.0
     * - Since: 1.4
     * > Note: This is very specific to dBase 7 level files. Also note that **this is an experimental feature and still under development!**
     */
    public var field_properties: FieldPropertiesStructure = FieldPropertiesStructure()
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
     * The default length for the timestamp field
     * - Version: 1.0
     * - Since: 1.3
     */
    public static let TIMESTAMP_COUNT: Int = 8
    /**
     * The default value an autoincrement field begins with
     * - Version: 1.0
     * - Since: 1.4
     */
    public static let DEFAULT_AUTOINCREMENT_VALUE: Int = 1
    
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
     * - Version: 1.1
     * - Since: 1.0
     */
    public func canAddColumns() -> Bool {
        return !self.isColumnLocked
    }
    
    /**
     * Adds a column to the data table. Time complexity: O(1)
     * - Parameters:
     *  - name: Required. The column name to add
     *  - type: Required. The type of data the column conforms to
     *  - len: Required. The field maximum length. Maximum value 254 allowed
     * - Throws: An error if column adding is locked or the column name is not valid
     * - Version: 1.2
     * - Since: 1.0
     * > Note: This function has been deprecated. Use the better addColumn() function that accepts a DBFColumn as the argument which doesn't throw any errors (hence a do-catch block isn't needed for adding columns!)
     */
    @available(*, deprecated, message: "Usage of addColumn(name:,dataType:,count:) has been deprecated. Use addColumn(_:) instead.")
    public func addColumn(with name: String, dataType type: ColumnType, count len: Int) throws {
        // make sure we are allowed to add columns to the list
        if self.isColumnLocked {
            throw DBFError.COLUMN_ADD_ERR("Cannot add columns to DBF table because column adding is locked")
        }
        // the column name length is also restricted to 32
        if name.count > 32 {
            throw DBFError.COLUMN_ADD_ERR("The column name must be <= 32 characters long")
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
        } else if type == .TIMESTAMP && lenm != DBFTable.TIMESTAMP_COUNT {
            lenm = DBFTable.TIMESTAMP_COUNT
            os_log("Incorrect Timestamp field length given \"\(len)\". It was auto-corrected to \(DBFTable.TIMESTAMP_COUNT) {DBFTable.TIMESTAMP_COUNT}")
        }
        
        // make sure len is in proper amount
        if (lenm < 1 || lenm > 254) {
            throw DBFError.COLUMN_ADD_ERR("Invalid number given for column length. Length should be 1 <= x <= 254 and is \(len)")
        }
        self.columns.append(DBFColumn(columnType: type, name: name, count: lenm))
    }
    /**
     * Adds a column to the table
     * - Parameters:
     *  - col: Required. The DBF Column (field) to add
     * - Version: 1.0
     * - Since: 1.4
     */
    public func addColumn(_ col: DBFColumn) {
        // stop if column adding is not allowed
        if self.isColumnLocked {
            Logger().warning("Column adding is locked. The column was not added to the DBFTable.")
            return
        }
        // validate general column details
        
        var edited: DBFColumn = col // in case we need to edit info
        
        // validate the name
        if edited.name.isEmpty {
            fatalError("Column (field) name cannot be empty.")
        }
        
        // a column name can only have alphanumeric characters and underscores
        if !edited.name.containsOnlyAlphaNumericsAndUnderscores() {
            Logger().warning("WARNING: Column (field) names should only contain alphanumerical characters and underscores. Data could be written inaccurately.")
        }
        
        let expected_length: Dictionary<ColumnType, Int> = [
            .AUTOINCREMENT: DBFTable.LONG_COUNT,
            .MEMO: DBFTable.MEMO_COUNT,
            .OLE: DBFTable.MEMO_COUNT,
            .BINARY: DBFTable.MEMO_COUNT,
            .LONG: DBFTable.LONG_COUNT,
            .DOUBLE: DBFTable.DOUBLE_COUNT,
            .DATE: DBFTable.DATE_COUNT,
            .TIMESTAMP: DBFTable.TIMESTAMP_COUNT
        ]
        
        // verify that count is proper
        if expected_length[col.columnType] != nil {
            if col.count != expected_length[col.columnType]! {
                os_log("Incorrect field length given for column of type \(col.columnType.rawValue). It was auto-corrected to \(expected_length[col.columnType]!)")
                edited = DBFColumn(columnType: col.columnType, name: col.name, count: col.count, next_autoincrement_value: col.next_autoincrement_value, has_index_in_mdx_file: col.has_index_in_mdx_file, decimal_count: col.decimal_count)
            }
        }
        
        // verify that count < 255
        if edited.count >= 255 || edited.count < 1 {
            Logger().error("A DBF column (field) can only have a length of 254 at maximum but \(edited.count) was given for the field with name \"\(edited.name)\". The column was not added to the table.")
            return
        }
        
        // autoincrement should also be valid
        // it cannot be less than 1
        if let ai_value = edited.next_autoincrement_value, ai_value < 1 && edited.columnType == .AUTOINCREMENT {
            Logger().error("The autoincrement value for the field with name \"\(edited.name)\" must be greater than 0. The value was set to \(ai_value).")
            return
        }
        
        // check if this is autoincrement and no next autoincrement value was set
        if edited.columnType == .AUTOINCREMENT && edited.next_autoincrement_value == nil {
            // set it up to default
            Logger().warning("Autoincrement value for the field with name \"\(edited.name)\" was not set. It will be set to 1.")
            edited.next_autoincrement_value = DBFTable.DEFAULT_AUTOINCREMENT_VALUE
        }
        
        // should be good to add -- the writer/reader will handle the field name length
        self.columns.append(edited)
    }
    /**
     * Updates a column at a given index
     * - Parameters:
     *  - at: Required. The index of the column to update
     *  - updated: Required. The column data to update
     * - Version: 1.0
     * - Since: 1.4
     * > Note: All data except the columnType can be modified
     */
    public func updateColumn(at index: Int, updated: DBFColumn) {
        // verify index position
        if index < 0 || index >= self.columns.count {
            fatalError("Index out of range: There are only \(self.columns.count) columns in this table and index \(index) was passed in.")
        }
        
        var edited: DBFColumn = updated // for editing if needed
        
        // make sure that column type is not being modified
        if self.columns[index].columnType != updated.columnType {
            fatalError("Column type are an immutable property.")
        }
        
        // validate the name
        if edited.name.isEmpty {
            fatalError("Column (field) name cannot be empty.")
        }
        
        // a column name can only have alphanumeric characters and underscores
        if !edited.name.containsOnlyAlphaNumericsAndUnderscores() {
            Logger().warning("WARNING: Column (field) names should only contain alphanumerical characters and underscores. Data could be written inaccurately.")
        }
        
        let expected_length: Dictionary<ColumnType, Int> = [
            .AUTOINCREMENT: DBFTable.LONG_COUNT,
            .MEMO: DBFTable.MEMO_COUNT,
            .OLE: DBFTable.MEMO_COUNT,
            .BINARY: DBFTable.MEMO_COUNT,
            .LONG: DBFTable.LONG_COUNT,
            .DOUBLE: DBFTable.DOUBLE_COUNT,
            .DATE: DBFTable.DATE_COUNT,
            .TIMESTAMP: DBFTable.TIMESTAMP_COUNT
        ]
        
        // verify that count is proper
        if expected_length[updated.columnType] != nil {
            if updated.count != expected_length[updated.columnType]! {
                os_log("Incorrect field length given for column of type \(updated.columnType.rawValue). It was auto-corrected to \(expected_length[updated.columnType]!)")
                edited = DBFColumn(columnType: updated.columnType, name: updated.name, count: updated.count, next_autoincrement_value: updated.next_autoincrement_value, has_index_in_mdx_file: updated.has_index_in_mdx_file, decimal_count: updated.decimal_count)
            }
        }
        
        // verify that count < 255
        if edited.count >= 255 || edited.count < 1 {
            Logger().error("A DBF column (field) can only have a length of 254 at maximum but \(edited.count) was given for the field with name \"\(edited.name)\". The column was not updated.")
            return
        }
        
        // autoincrement should also be valid
        // it cannot be less than 1
        if let ai_value = edited.next_autoincrement_value, ai_value < 1 {
            Logger().error("The autoincrement value for the field with name \"\(edited.name)\" must be greater than 0. The value was set to \(ai_value).")
            return
        }
        
        // check if this is autoincrement and no next autoincrement value was set
        if edited.columnType == .AUTOINCREMENT && edited.next_autoincrement_value == nil {
            // set it up to default
            Logger().warning("Autoincrement value for the field with name \"\(edited.name)\" was not set. It will be set to 1.")
            edited.next_autoincrement_value = DBFTable.DEFAULT_AUTOINCREMENT_VALUE
        }
        
        // also other info is good for updating
        self.columns[index] = edited
    }
    /**
     * Increments the next autoincrement value of a column given its index
     * - Parameters:
     *  - at: Required. The index of the column
     * - Version: 1.0
     * - Since: 1.4
     */
    public func incrementAutoIncrementValue(at index: Int) {
        // validate index
        if index < 0 || index >= self.columns.count {
            fatalError("Index out of range: There are only \(self.columns.count) columns in this table and index \(index) was passed in.")
        }
        
        // give a warning if the column is not a autoincrement column
        if self.columns[index].columnType != .AUTOINCREMENT {
            Logger().warning("Column with name \"\(self.columns[index].name)\" is not an autoincrement column. Its next autoincrement value was not incremented.")
            return
        }
        
        // increment
        self.columns[index].next_autoincrement_value! += 1
    }
    
    /**
     * Adds a row to the DBF table. Time complexity: O(1)
     * - Parameters:
     *  - data: Required. An array of string to add for the data
     * - Throws: An error if the adding column property is not locked or if the number of values in data is not the same as the number of columns
     * - Version: 1.0
     * - Since: 1.0
     * > Note: This function has been deprecated. Use addRow(data:,is\_deleted) (or just addRow(data:)) instead which lets you put in the exact same paratermeters and not have to call the function in a do-catch block!
     */
    @available(*, deprecated, message: "Usage of addRow(with:) has been deprecated. Use addRow(data:,is_deleted:) instead.")
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
     * > Note: Usage of this function is deprecated. Use addRow(data:,is\_deleted:) instead which allows you to input the same exact parameters but without having to call the function in a do-catch block!
     */
    @available(*, deprecated, message: "Usage of addRow(with:, deleted:) is deprecated. Use addRow(data:,is_deleted:) instead.")
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
     * Adds a row to the table
     * - Parameters:
     *  - data: Required. The data to add
     *  - is_deleted: Required. If the record is marked as deleted
     * - Version: 1.0
     * - Since: 1.4
     */
    public func addRow(data: [String], is_deleted: Bool = false) {
        // make sure column adding is locked
        if !self.isColumnLocked {
            fatalError("Cannot add rows to DBFTable because column adding is not locked")
        }
        
        // validate the length
        if data.count != self.columns.count {
            fatalError("Cannot add a row to the table because it does not have the same number of values as the number of columns added in the table. Row value count: \(data.count), Column count: \(self.columns.count)")
        }
        
        // check if record is deleted
        if is_deleted {
            self.deleted_rows.append(data)
            return
        }
        
        // add to regular
        self.rows.append(data)
    }
    /**
     * Updates the row entirely given its index as given in getRows()
     * - Parameters:
     *  - at: Required. The index to update the row in
     *  - with: Required. The new data
     * - Version: 1.0
     * - Since: 1.4
     */
    public func updateRow(at index: Int, with data: [String]) {
        // verify index is valid
        if index >= self.rows.count || index < 0 {
            fatalError("Index out of bounds. There are \(self.rows.count) non-deleted rows and index given is \(index).")
        }
        
        // verify new data
        if data.count != self.columns.count {
            fatalError("Cannot update a row in the table because it does not have the same number of values as the number of columns added in the table. Row value count: \(data.count), Column count: \(self.columns.count)")
        }
        
        self.rows[index] = data
    }
    /**
     * Updates the (deleted) row entirely given its index as given in getDeletedRows()
     * - Parameters:
     *  - at: Required. The index to update the row in
     *  - with: Required. The new data
     * - Version: 1.0
     * - Since: 1.4
     */
    public func updateDeletedRow(at index: Int, with data: [String]) {
        // basically identical implementation to updateRow but look into deleted_rows
        // verify index is valid
        if index >= self.deleted_rows.count || index < 0 {
            fatalError("Index out of bounds. There are \(self.deleted_rows.count) deleted rows and index given is \(index).")
        }
        
        // verify new data
        if data.count != self.columns.count {
            fatalError("Cannot update a row in the table because it does not have the same number of values as the number of columns added in the table. Row value count: \(data.count), Column count: \(self.columns.count)")
        }
        
        self.deleted_rows[index] = data
    }
    /**
     * Updates a row (record) to be marked as deleted
     * - Parameters:
     *  - at: Required. The index of the row to update
     *  - in_deleted_rows: If the row to update the deletion status is already deleted
     *  - mark_deleted: The new deleted status of the row
     * - Version: 1.0
     * - Since: 1.4
     */
    public func updateRowDeletionStatus(at index: Int, in_deleted_rows: Bool, mark_deleted: Bool) {
        // validate index
        let count_check: Int = in_deleted_rows ? self.deleted_rows.count : self.rows.count
        if index >= count_check || index < 0 {
            fatalError("Index out of bounds. There are \(count_check) rows and index given is \(index).")
        }
        
        // we are looking into deleted records?
        if in_deleted_rows {
            if mark_deleted {
                // do nothing as record is already marked as deleted!
                return
            }
            // append into normal rows
            self.rows.append(self.deleted_rows[index])
            
            // remove from old
            self.deleted_rows.remove(at: index)
            return
        }
        
        if !mark_deleted {
            // do nothing as record is already marked as not deleted!
            return
        }
        
        // append into deleted rows
        self.deleted_rows.append(self.rows[index])
        
        // remove from old
        self.rows.remove(at: index)
    }
    /**
     * Toggles the deletion status of a row
     * - Parameters:
     *  - at: Required. The index of the row
     *  - in_deleted_rows: Required. If the row is already marked as deleted
     * - Version: 1.0
     * - Since: 1.4
     */
    public func toggleRowDeletionStatus(at index: Int, in_deleted_rows: Bool) {
        if in_deleted_rows {
            // verify index
            if index >= self.deleted_rows.count || index < 0 {
                fatalError("Index out of bounds. There are \(self.deleted_rows.count) deleted rows and index given is \(index).")
            }
            
            // update status to non deleted
            self.updateRowDeletionStatus(at: index, in_deleted_rows: true, mark_deleted: false)
            return
        }
        
        // verify index
        if index >= self.rows.count || index < 0 {
            fatalError("Index out of bounds. There are \(self.rows.count) non-deleted rows and index given is \(index).")
        }
        
        self.updateRowDeletionStatus(at: index, in_deleted_rows: false, mark_deleted: true)
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
     * > Note: This function has been deprecated. Use getTotalBytesHeader(version:) with a parameter denoting the version to generate the header bytes for. This helps to generate the header bytes more accurately. To get the exact same results as this function, call getTotalBytesHeader(version: .DBASE3)
     */
    @available(*, deprecated, message: "Usage of getTotalBytesHeader has been deprecated. Use getTotalBytesHeader(version:) instead (set version to DBASE3 to get the same results as this function).")
    public func getTotalBytesHeader() -> Int {
        var totalBytes: Int = 32 * self.columns.count + 1
        totalBytes += 32
        return totalBytes
    }
    /**
     * Gets the total number of bytes the header of the table will take up in the DBF file. Time complexity: O(1)
     * - Parameters:
     *  - version: Required. Gets the bytes for the header of a given dbase version. Defaults to dbase 3
     * - Returns: An integer representing how many bytes the header takes up
     * - Version : 1.0
     * - Since: 1.4
     */
    public func getTotalBytesHeader(version: DbaseVersion = .DBASE3) -> Int {
        // check the dbase version
        if version == .DBASE7 {
            // each field descriptor is about 48 bytes
            // add it up for each column
            var totalBytes: Int = 48 * self.columns.count + 1
            // the "first" part of the header takes up about 68 bytes
            // so add that
            totalBytes += 68
            // we now need to compute the field properties structure
            totalBytes += self.field_properties.dbfEncodingSize(version: .DBASE7)
            return totalBytes
        }
        
        // this isn't any different from the previous version of DBFKit
        // compute in same way as the deprecated function
        var totalBytes: Int = 32 * self.columns.count + 1
        totalBytes += 32
        return totalBytes
    }
    
    /**
     * Gets the total number of bytes per record of the table that will take up in the DBF file. Time complexity: O(n) where n is the number of columns
     * - Returns: An integer representing how many bytes all the rows will take up
     * - Version: 1.1
     * - Since: 1.0
     */
    public func getTotalBytesPerField() -> Int {
        var totalBytes: Int = 0
        for i in self.columns {
            totalBytes += i.count
        }
        totalBytes += 1
        totalBytes = totalBytes * self.getTotalRecordCount()
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
     * Gets the date given how it is stored in the DBF file (i.e. converts out of DBFTable.getDateValue)
     * - Parameters:
     *  - dbf_value: Required. How the date is stored in the dbf file
     * - Returns: The date stored in Swift form (or nil on error)
     * - Version: 1.0
     * - Since: 1.4
     */
    public static func getDateFromDBFValue(dbf_value: String) -> Date? {
        // we can use date formatter
        let df: DateFormatter = DateFormatter()
        df.dateFormat = "yyMMdd"
        let d: Date? = df.date(from: dbf_value)
        
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
    /**
     * Converts the date and time into a timestamp
     * - Parameters:
     *  - date: Required. The date to convert
     *  - hours: Required. The hour
     *  - minutes: Required. The minute
     *  - seconds: Required. The second
     * - Returns: A string representation of the timestamp
     * - Version: 1.0
     * - Since: 1.3
     */
    private static func convertToTimestamp(date: Date, hours: Int, minutes: Int, seconds: Int) -> String {
        // we need to compute how many days away date is from the date 01/01/4713 BC
        var old_date: DateComponents = DateComponents()
        old_date.month = 1
        old_date.day = 1
        old_date.year = -4713
        
        let fd = Calendar.current.startOfDay(for: Calendar.current.date(from: old_date)!)
        let ed = Calendar.current.startOfDay(for: date)
        let num_days = Calendar.current.dateComponents([.day], from: fd, to: ed).day! + 1
        
        // as for the time, we need to convert it all into milliseconds
        let ms: Int = ((hours * 60 * 60) + (minutes * 60) + seconds) * 1000 // there are 1000 ms in seconds
        
        // we will just use a space to separate the two core values that will be stored in the timestamp
        return "\(num_days) \(ms)"
    }
    /**
     * Converts the date into a timestamp
     * - Parameters:
     *  - date: Required. The date to convert
     * - Returns: A string representation of the time
     * - Version: 1.0
     * - Since: 1.3
     */
    public static func convertToTimestamp(date: Date) -> String {
        let d: DateComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        
        // just call the private static function which holds the full conversion
        return DBFTable.convertToTimestamp(date: date, hours: d.hour!, minutes: d.minute!, seconds: d.second!)
    }
    /**
     * Converts a timestamp to a date (which should be readable)
     * - Parameters:
     *  - timestamp: Required. The string (which should appear similar to how convertToTimestamp generates) to convert
     * - Returns: nil on failure and the date on success
     * - Version: 1.0
     * - Since: 1.3
     * > Note: this function only converts out of what convertToTimestamp generates (or what is read from the DBF file, both values are written in the exact same way for the sake of simplicity). The years, month, day, hour, minute, second are all stored into the single Date class
     */
    public static func convertTimestampToDate(timestamp: String) -> Date? {
        // lets first divide up the strings into two parts
        let parts: [String] = timestamp.split(separator: " ").map(String.init)
        
        // assert length is proper
        if parts.count != 2 {
            return nil
        }
        
        let pt1: Int? = Int(parts[0])
        let pt2: Int? = Int(parts[1])
        
        // lets make sure pt1 and pt2 are not nil
        if pt1 == nil || pt2 == nil {
            return nil
        }
        
        var dc: DateComponents = DateComponents()
        dc.day = 1
        dc.month = 1
        dc.year = -4713
        let begin_date: Date = Calendar.current.date(from: dc)!
        
        // lets first parse the first part of the array
        // this number should represent the number of days since 01/01/4713 BC
        // so we have to compute what year, month, and day these number of days represent
        let start_date: Date = Calendar.current.date(byAdding: .day, value: pt1!, to: begin_date)!
        
        // now make the components of start_date
        var comp: DateComponents = Calendar.current.dateComponents([.year, .month, .day], from: start_date)
        
        // now comes the easy part
        // we need to convert our milliseconds to hours/minutes/seconds
        // begin by divindg by 1000 to convert the ms to seconds
        let secondsk: Int = pt2! / 1000
        
        var seconds: Int = secondsk + 0
        var minutes: Int = 0
        var hours: Int = 0
        
        // lets see if there are at least 60 seconds in seconds
        if seconds >= 60 {
            // in that case lets move as many seconds as we can into minutes
            minutes = Int(floor(Double(seconds) / 60.0))
            seconds -= minutes * 60
        }
        
        // we will do the same thing for minutes
        if minutes >= 60 {
            hours = Int(floor(Double(minutes) / 60.0))
            minutes -= hours * 60
        }
        
        comp.hour = hours
        comp.minute = minutes
        comp.second = seconds
        
        // okay we are good!
        // turn the components into the actual date
        let end_date: Date = Calendar.current.date(from: comp)!
        
        return end_date
    }
}

/**
 * The core writer class
 * - Version: 1.2
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
     * The language driver ID. Defaults to 0x00 (no specific driver set)
     * - Version: 1.0
     * - Since: 1.4
     * > Note: All possible values can be found here: https://stackoverflow.com/a/52957718
     */
    public var language_driver_id: UInt8 = 0x00
    /**
     * The language driver name put in the dBase level 7 file. Defaults to no specific driver set
     * - Version: 1.0
     * - Since: 1.4
     * > Note: All possible values can be found in the same link as given in _language\_driver\_id_
     */
    public var language_driver_name: String = ""
    /**
     * If the DBF file has a production MDX file
     * - Version: 1.0
     * - Since: 1.4
     */
    public var has_production_mdx_file: Bool = false
    /**
     * If the DBF file has an incomplete dBase 4 transaction
     * - Version: 1.0
     * - Since: 1.4
     * > Note: An incomplete transaction usually refers to a database operation that has started but not properly finalized. The flag usually indicates potential data inconsistency or corruption
     */
    public var has_incomplete_transaction: Bool = false
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
     * The size of one block in a DBT file
     * - Version: 1.0
     * - Since: 1.4
     * > Note: Custom block sizes can ONLY be defined in dBase 7 level files. Also note that this number must be between 1 - 63 (see https://www.dbase.com/help/9_2/IDE/IDH_IDE_SET_BLOCKSIZE.htm). Also note how this gets processed as it is a bit weird. The actual size of the dbt block will be the number you input here multiplied by 512. So if you, for instance, put 2 here, one DBT block will be 1024 bytes (2 \* 512 = 1024)
     */
    public var dbt_block_size: Int = 1
    
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
     * If the data exceeds the maximum storage a dbf file is allowed to take up
     * - Parameters:
     *  - d: Required. The data that will be written
     * - Returns: A boolean indicating if the dbf file takes up more storage than what it is allowed to take up
     * - Version: 1.0
     * - Since: 1.4
     */
    private func exceedsMaximumDBFFileSize(_ d: Data) -> Bool {
        // a dbf file usually cannot take up more than 2GB of storage
        // see also: https://www.dbase.com/Knowledgebase/faq/dBASE_Limits_FAQ.html
        let two_gb: Int = 2 * 1024 * 1024 * 1024
        
        return d.count > two_gb
    }
    /**
     * Updates the next available dbt block info to a new version in the dbt data
     * - Parameters:
     *  - to: Required. The index representing the next available block
     * - Version: 1.0
     * - Since: 1.4
     */
    private func updateDbtBlockInfo(to: Int) {
        // if nothing was initialized, break out of it
        guard self.dbt_data != nil else { return }
        // convert to uint32 and get the little endian
        let next_block: UInt32 = UInt32(to).littleEndian
        // now insert
        // bytes 0-3 represent the next block number
        let bb: [UInt8] = withUnsafeBytes(of: next_block, Array.init)
        self.dbt_data![0] = bb[0]
        self.dbt_data![1] = bb[1]
        self.dbt_data![2] = bb[2]
        self.dbt_data![3] = bb[3]
    }
    /**
     * Initializes the dbt data
     * - Parameters:
     *  - version: Required. The dbase version being used here
     * - Version: 1.0
     * - Since: 1.2
     */
    private func initDBT(version: DbaseVersion = .DBASE3) {
        // this function assumes that upon initialization, there is at least one field in the dbf table that makes use of memo fields
        // so for now we will intialize this dbt data with two blocks
        // valid block size
        if self.dbt_block_size <= 0 {
            fatalError("A DBT block size cannot be <= 0")
        }
        // one block consists of 512 bytes in it
        self.dbt_data = Data(count: 512)
        
        // we only put one thing in the header, the next index where data can be inserted
        // in our case, this is simply one
//        self.dbt_data![0] = 1
        // bytes 0-3 is index of next block
        // store as 4 bytes
        self.updateDbtBlockInfo(to: 1) // next index is 1
        
        // set version to dBase III
        self.dbt_data![16] = 0x03
        
        // set max size if applicable
        if version == .DBASE7 || version == .DBASE4_WITH_MEMO {
            // only allowed in dbase 7
            // set block size
            if self.dbt_block_size > 63 {
                Logger().warning("DBT block size (in DBFWriter.dbt_block_size) should be between 1 and 63, but \(self.dbt_block_size) was given. Data could be written incorrectly.")
            }
            
            // reset dbt data briefly
            self.dbt_data = Data(count: 512 * self.dbt_block_size)
            self.updateDbtBlockInfo(to: 1)
            // fifth byte represents block size
//            self.dbt_data![5] = UInt8(self.dbt_block_size) //TODO: IS THIS STILL USED IN DBASE 7
            let converted: [UInt8] = [
                UInt8(self.dbt_block_size & 0xFF),
                UInt8((self.dbt_block_size >> 8) & 0xFF),
                UInt8((self.dbt_block_size >> 16) & 0xFF),
            ]
            self.dbt_data![5] = converted[0]
            self.dbt_data![6] = converted[1]
            self.dbt_data![7] = converted[2]
            
            // bytes 20-21 represent the actual length of one block
            let one_block_length = 512 * self.dbt_block_size
            let actual_length = [UInt8((one_block_length.littleEndian >> 8) & 0x00FF), UInt8(one_block_length.littleEndian & 0x00FF)]
            
            self.dbt_data![20] = actual_length[0]
            self.dbt_data![21] = actual_length[1]
            
            // bytes 8-15 store the DBF file name
            // this should only include the name (without the .dbf extension)
            // the filename is stored just like DBFTable.DBFColumn.STRING (in ASCII)
            // HOWEVER, it is NOT requred to have the file name stored here
            // since this function doens't already accept the filename as an argument, we will just not include it
        }
        
        // regardless set the last two bytes to terminators
        self.dbt_data![self.dbt_data!.count - 1] = 0x1A
        self.dbt_data![self.dbt_data!.count - 2] = 0x1A
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
     *  - version: Required. The version the bytes are being written to
     * - Version: 1.1
     * - Since: 1.2
     */
    private func writeBytesDBT(memo: String, version: DbaseVersion = .DBASE3) {
        // intialize dbt data if needed
        if self.dbt_data == nil {
            self.initDBT(version: version)
        }
        // lets first convert our string memo into the data buffer. We will convert all the characters into ascii character like we have done so far with regular data
        var data: Data = memo.data(using: .ascii)!
        
        var max_size: Int = 512
        if version == .DBASE7 || version == .DBASE4_WITH_MEMO {
            max_size = 512 * self.dbt_block_size
        }
        
        // check versions
        
        // one dbt block consists of 512 bytes
        // first, lets see if the current data we write exceeds this
//        if data.count >= 510 { // we compare it to 510 because the last two bytes of the block must represent the end of block
        if data.count >= max_size - 2 {
            // we need to figure out how many blocks this stretches over
//            let block_count: Int = Int(ceil(Double(data.count) / 512.0))
            let block_count: Int = Int(ceil(Double(data.count) / Double(max_size)))
            
            // update next available block add
            self.dbt_next_block_index += block_count + 1 //FIX: ISSUE #3
            
            // our block numbers may not look very nice now
            // one block should have exactly 512 bytes in it
            // since this data right now expands over 1 block, we need to figure out exactly how many bytes to add, so that number is divisible by 512
//            let num_bytes_add: Int = data.count % 512
            let num_bytes_add: Int = data.count % max_size
            data.append(Data(count: num_bytes_add))
            data[data.count - 1] = 0x1A
            data[data.count - 2] = 0x1A
            
            // now append to dbt_data
            self.dbt_data!.append(data)
            
            // lastly set the new byte 0 to whatever dbt_data is
            self.updateDbtBlockInfo(to: self.dbt_next_block_index)
        } else {
            // in that case, we set the last two bytes of data to 0x1A (this represents the end of the memo)
            // then append it to dbt_data
//            data.append(Data(count: 512 - data.count))
            data.append(Data(count: max_size - data.count))
            data[data.count - 1] = 0x1A
            
            self.dbt_data!.append(data)
            
            // increment next available index
            self.dbt_next_block_index += 1
            
            // and set that to byte 0 of dbt_data
            self.updateDbtBlockInfo(to: self.dbt_next_block_index)
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
     *  - version: Required. The dbase version to write under
     * - Throws: An error on failure
     * - Version: 1.3
     * - Since: 1.1
     */
    private func writeBytesRecord(buffer: UnsafeMutablePointer<Data>, record: [String], current_offset: UnsafeMutablePointer<Int>, encoding: String.Encoding, version: DbaseVersion = .DBASE3) throws {
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
                self.writeBytesDBT(memo: z, version: version)
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
                    if Int(value) == nil && Double(value) == nil {
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
            } else if self.dbfTable.getColumns()[zi].columnType == .TIMESTAMP {
                // split up string
                let split: [String] = z.split(separator: " ").map(String.init)
                // validate length of split is 2
                if split.count != 2 {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) is not a valid timestamp")
                }
                
                // now make sure boths parts are integers
                let pt1: Int? = Int(split[0])
                let pt2: Int? = Int(split[1])
                
                if pt1 == nil || pt2 == nil {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) is not a valid timestamp")
                }
                
                // both integers should be converted into Int32
                var pt132: Int32 = Int32(pt1!)
                var pt232: Int32 = Int32(pt2!)
                
                // now make the bytes
                let b1: [UInt8] = withUnsafeBytes(of: &pt132, Array.init)
                let b2: [UInt8] = withUnsafeBytes(of: &pt232, Array.init)
                
                // merge both arrays
                let b3: [UInt8] = b1 + b2
                
                // write to buffer
                for j in b3 {
                    buffer.pointee[current_offset.pointee] = j
                    current_offset.pointee += 1
                }
                
                // adjust zi as needed
                zi += 1
                
                continue
            } else {
                // make sure z is not larger than the max length allowed for the column
                guard var converted: Data = z.data(using: encoding) else {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) cannot be converted to selected encoding")
                }
                let col = self.dbfTable.getColumns()[zi]
                if converted.count > col.count {
                    throw DBFError.ROW_ADD_ERR("Row at index \(zi), element \(z) exceeds the maximum length for column")
                }

                // Pad with zeroes
                if converted.count < col.count {
                    let extraData = Array(repeating: UInt8(0), count: col.count - converted.count)
                    converted.append(contentsOf: extraData)
                }

                for j in 0 ..< converted.count {
                   let byte = converted[j]
                   buffer.pointee[current_offset.pointee] = byte
                   current_offset.pointee += 1
                }
            }

            zi += 1
        }
    }
    
    /**
     * Writes up the bytes for the dbf data. Time complexity: O((n \* m) + (r \* n \* m)) where n is the number of columns, m is the maximum length of each column, and r is the number of rows
     * - Returns: A buffer
     * - Throws: An error on write
     * - Version: 1.3
     * - Since: 1.0
     */
    private func writeBytes(encoding: String.Encoding) throws -> Data {
        // set up any warnings as needed
        // reset dbt info as needed
        self.deinitDBT()
        let header_len: Int = self.dbfTable.getTotalBytesHeader(version: .DBASE3)
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
        
        // check if the number of bytes in one record exceeds 4000
        if one_record_len > 4000 {
            // dbf files have limitations: https://www.dbase.com/Knowledgebase/faq/dBASE_Limits_FAQ.html
            Logger().warning("WARNING: dBase III does not support dbf files with a record containing more than 4000 bytes. File data may be written inaccurately.")
        }
        
        // dBase 3 also limits us to 65535 records
        if num_records > 65535 {
            Logger().warning("WARNING: dBase III does not support dbf files with more than 65,535 records. File data may be written inaccurately.")
        }
        
        // incomplete transaction flag
        if self.has_incomplete_transaction {
            buffer[14] = 0x01
        }
        
        // mark encryption flag
        if self.encryption_flag {
            buffer[15] = 1
        }
        
        // byte 28 is produciton mdx stuff
        buffer[28] = self.has_production_mdx_file ? 0x01 : 0x00
        
        // byte 29 is language driver id
        buffer[29] = self.language_driver_id
        
        // columns (field descriptors)
        let cols: [DBFTable.DBFColumn] = self.dbfTable.getColumns()
        // check if we have over 128 fields
        if cols.count > 128 {
            // note that dBase 4 and dBase 5 for somwe weird reason allows up to 255 fields (but keeps the file structure the same!)
            // since dBase 4 and dBase 5 use the exact same identifier as dBase 3 (0x03), we have no way of checking what version we writing in!
            // so perhaps in a future release, we change this functionality and keep the following beta until then
            Logger().warning("WARNING: dBase III does not support dbf files with more than 128 fields. dBase 4 and dBase 5 support up to 255 fields. Currently, \(cols.count) are being attempted to be written. File data may be written inaccurately.")
        }
        // loop over all cols and set them up
        var current_offset: Int = 32
        var byteoff: Int = 32
        for i in cols {
            // field name (in ascii)
            // in order to achieve this in ascii, we have to loop over each character and get the ascii char code
            // verify that the column name is not more than 10 chars long
            if i.name.count > 10 {
                throw DBFError.COLUMN_ADD_ERR("dBase 3 DBF files only support 10 character field names")
            }
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
            // also give any warnings for column type
            // in case an unsupported type is used
            if i.columnType == .AUTOINCREMENT || i.columnType == .LONG || i.columnType == .DOUBLE || i.columnType == .TIMESTAMP {
                Logger().warning("WARNING: dBase III does not support \(i.columnType.rawValue) fields. File data may be written inaccurately.")
            }
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
        assert(current_offset == header_len)
        var iter = 0
        for i in self.dbfTable.getRows() {
            // add space to mark row present
            buffer[current_offset] = 0x0020
            current_offset += 1
            try self.writeBytesRecord(buffer: &buffer, record: i, current_offset: &current_offset, encoding: encoding)
            iter += 1
        }
        // add any deleted rows
        for i in self.dbfTable.getDeletedRows() {
            // deleted rows are marked with an '*'
            buffer[current_offset] = 0x2A
            current_offset += 1
            try self.writeBytesRecord(buffer: &buffer, record: i, current_offset: &current_offset, encoding: encoding)
        }
        // eof flag
        buffer[current_offset] = 0x1A
        
        // we will make one last edit
        // if a dbt was written, we must reflect that in byte 0
        if self.dbt_data != nil {
            buffer[0] = 0x83 // this represents DBF version 3 + included DBT file
        }
        
        // verify size
        if self.exceedsMaximumDBFFileSize(buffer) {
            Logger().warning("WARNING: DBF file written to exceeds the maximum size allowable for DBF files (2GB). File data may be written inaccurately.")
        }
        
        return buffer
    }
    /**
     * Writes up the bytes for dBase level 7
     * - Parameters:
     *  - encoding: Required. The encoding to use
     * - Returns: The written up data
     * - Throws: An error upon writing
     * - Version: 1.0
     * - Since: 1.4
     * > Note: Writing dBase 7 level files is an experimental feature at the moment!
     */
    private func writeBytesDbase7(encoding: String.Encoding) throws -> Data {
        // give a brief warning about this experimental feature
        os_log("WARNING: writing dBase 7 is not fully tested yet. Use with caution.")
        
        // reset dbt info as needed
        self.deinitDBT()
        
        // the first part of the file is identical to dBase level 3
        let header_len: Int = self.dbfTable.getTotalBytesHeader(version: .DBASE7)
        let bytes_len: Int = self.dbfTable.getTotalBytesPerField()
        let one_record_len: Int = self.dbfTable.getTotalBytesOneRecord()
        let buffer_len: Int = header_len + bytes_len + 1
        let num_records: Int = self.dbfTable.getTotalRecordCount()
        var buffer: Data = Data(repeating: 0, count: buffer_len)
        // write up header
        // byte 0 should be dbf version
        buffer[0] = DbaseVersion.DBASE7.rawValue
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
        
        // now perform checks
        if one_record_len > 32767 {
            // dBase 7 permits one record to have up to 32,767 bytes
            Logger().warning("WARNING: dBase 7 does not allow one record to have more than 32,767 bytes. File data may be written inaccurately.")
        }
        
        // byte 14 is incomplete transaction flag
        buffer[14] = self.has_incomplete_transaction ? 0x01 : 0x00
        
        // byte 15 is encryption flag
        buffer[15] = self.encryption_flag ? 0x01 : 0x00
        
        // dbase 7 makes things complicated here as more data is needed to be inputted
        
        // byte 28 is production mdx file info
        buffer[28] = self.has_production_mdx_file ? 0x01 : 0x00
        
        // byte 29 is language driver id
        buffer[29] = self.language_driver_id
        
        // next 2 bytes are reserved (filled with 0)
        
        // bytes 32-63 is the language driver name
        // this should be no more than 32 chars long
        if self.language_driver_name.count > 32 {
            throw DBFError.COLUMN_ADD_ERR("Language driver name is too long (max 32 chars)")
        }
        
        // add all ascii chars
        var in_ascii: Data = self.language_driver_name.data(using: encoding)!
        // bump it up to 32 bytes
        in_ascii.append(Data(count: 32 - in_ascii.count))
        
        // now append
        var next_char: Int = 0
        for i in 32..<64 {
            buffer[i] = in_ascii[next_char]
            next_char += 1
        }
        
        // bytes 64-67 is reserved (filled with 0)
        
        // dbase 7 limits us to 1024 fields
        if self.dbfTable.getColumns().count > 1024 {
            Logger().warning("WARNING: dBase 7 only permits 1024 columns. File data may be written inaccurately.")
        }
        
        // bytes 68-n is columns
        var current_byte: Int = 68
        for i in self.dbfTable.getColumns() {
            // make sure that the field name is no more than 32 chars long
            if i.name.count > 32 {
                throw DBFError.COLUMN_ADD_ERR("dBase7 only permits field name to have a maximum of 32 chars only!")
            }
            
            // convert the field name to ascii
            var field_in_ascii: Data = i.name.data(using: .ascii)!
            field_in_ascii.append(Data(count: 32 - field_in_ascii.count))
            
            for k in 0..<32 {
                buffer[current_byte] = field_in_ascii[k]
                current_byte += 1
            }
            
            // next is field type
            buffer[current_byte] = i.columnType.rawValue.asciiValue!
            
            current_byte += 1
            
            // next is field length in binary
            buffer.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                bytes.storeBytes(of: UInt16(i.count), toByteOffset: current_byte, as: UInt16.self)
            }
            
            current_byte += 1
            
            // next is decimal count in binary
            buffer.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                bytes.storeBytes(of: UInt16(i.decimal_count ?? 0), toByteOffset: current_byte, as: UInt16.self)
            }
            
            current_byte += 3
            
            // next 2 bytes are reserved
            // we put production mdx next
            if i.has_index_in_mdx_file ?? false {
                buffer[current_byte] = 0x01
            }
            
            current_byte += 3
            
            // next two bytes are reserved
            
            // next is the next autoincrement value
            // check if this is an autoincrement field
            if i.columnType == .AUTOINCREMENT {
                // get byte spot at next column
                let byte_spot: Int = current_byte + 8
                // we have to represent this value as 4 bytes
                let auto_int: Int = i.next_autoincrement_value ?? 1
//                let bytes = withUnsafeBytes(of: auto_int.littleEndian, Array.init)
                let u32value: UInt32 = UInt32(truncatingIfNeeded: auto_int)
                let bytes: [UInt8] = [
                    UInt8(u32value & 0xFF),
                    UInt8((u32value >> 8) & 0xFF),
                    UInt8((u32value >> 16) & 0xFF),
                    UInt8((u32value >> 24) & 0xFF)
                ]
                
                // now add
                for i in bytes {
                    buffer[current_byte] = i
                    current_byte += 1
                }
                
                // increment to get to next column
                current_byte = byte_spot
            } else {
                // we fill with 0x00 (already done)
                // and just shift the byte
                current_byte += 8
            }
        }
        
        // include field column terminator
        buffer[current_byte] = 0x0D
        
        // next is the field propertie structure
        let field_properties_structure: Data = try self.dbfTable.field_properties.encodeToDBF(version: .DBASE7)
        
        // insert this into the buffer
//        buffer.append(field_properties_structure)
        current_byte += 1
        for k in 0..<field_properties_structure.count {
            buffer[current_byte] = field_properties_structure[k]
            current_byte += 1
        }
        
        // now we can insert the rows!
        // inserting records here is identical to dBase level 3
//        var current_offset: Int = current_byte + self.dbfTable.field_properties.dbfEncodingSize(version: .DBASE7)
        var current_offset: Int = current_byte + 0
        for i in self.dbfTable.getRows() {
            // add space to mark row present
            buffer[current_offset] = 0x0020
            current_offset += 1
            try self.writeBytesRecord(buffer: &buffer, record: i, current_offset: &current_offset, encoding: encoding, version: .DBASE7)
        }
        
        // add any deleted rows
        for i in self.dbfTable.getDeletedRows() {
            // deleted rows are marked with an '*'
            buffer[current_offset] = 0x2A
            current_offset += 1
            try self.writeBytesRecord(buffer: &buffer, record: i, current_offset: &current_offset, encoding: encoding, version: .DBASE7)
        }
        // eof flag
        buffer[current_offset] = 0x1A
        
        if self.exceedsMaximumDBFFileSize(buffer) {
            Logger().warning("WARNING: DBF file written to exceeds the maximum size allowable for DBF files (2GB). File data may be written inaccurately.")
        }
        
        // we are done
        return buffer
    }
    
    /**
     * Writes to a given DBF file.
     * - Parameters:
     *  - file: Required. A URL to the file to write the DBF data to
     *  - encoding: Required. The encoding to use for the file. Defaults to UTF-8
     *  - version: Required. The version to write the file under. Defaults to dBase 3
     * - Throws: An error on write
     * - Version: 1.1
     * - Since: 1.0
     */
    public func write(to file: URL, encoding: String.Encoding = .utf8, version: DbaseVersion = .DBASE3) throws {
        // get bytes
//        let buffer: Data = try self.writeBytes(encoding: encoding)
        let buffer: Data
        if version == .DBASE7 {
            buffer = try self.writeBytesDbase7(encoding: encoding)
        } else {
            // use dBase 3 level writing
            buffer = try self.writeBytes(encoding: encoding)
        }
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
    /**
     * Gets the index of the next available block in the DBT file
     * - Returns: The index of the next available block in the DBT file
     * - Version: 1.0
     * - Since: 1.4
     * > Note: This function **MUST** be executed **BEFORE** running DBFWriter.writeDBT as writeDBT de-initializes the next block index automatically after writing to the file. Generally speaking, you should run DBFWriter.write, call this function to retrieve the index, and then writeDBT in order to get the index
     */
    public func getDBTNextBlockIndex() -> Int {
        // it is assumed the DBFWriter.write(to:) was called before this function is being called
        // it is also assumed that at least one memo field was written to in DBFWriter.write(to:)
        // hence dbt_next_block_index is not 1
        // finally, it is also assumed that DBFWriter.writeDBT(to:) was not called yet
        return self.dbt_next_block_index
    }
}

// MARK: DBF READER

/**
 * A simple DBF file
 * - Version: 1.2
 * - Since: 1.0
 */
class DBFFile {
    
    // we will reserve a few variables blank (nil) until the file has been actually read
    
    /**
     * General info stored in the header of the DBT file
     * - Version: 1.0
     * - Since: 1.4
     * > Note: Data stored in this struct will appear differently depending on the version of the DBT file being read
     */
    struct DBTFileData {
        
        /// Version number stored in the DBT file
        /// - Version: 1.0
        /// - Since: 1.4
        /// > Note: The version number seems to be stored in dBase III DBT files but for some weird reason not in dBase 4 and beyond
        let version: UInt8?
        /// The index of the next block to append the data to
        /// - Version: 1.0
        /// - Since: 1.4
        let next_append_index: Int
        /// Size of blocks
        /// - Version: 1.0
        /// - Since: 1.4
        /// > Note: In dBase 3 files, this will always be 1 while in dBase 4 and beyond, this number could be bigger
        let block_size: Int
        /// The length of one block in the DBT file
        /// - Version: 1.0
        /// - Since: 1.4
        /// > Note: In dBase 3 files, this will always be 512 while in dBase 4 and beyond, this number could be bigger
        let block_length: Int
    }
    
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
    @available(*, deprecated, message: "Usage of filePath is deprecated. Use file_url instead.")
    private var filePath: String?
    /**
     * URL to the file to read
     * - Version: 1.0
     * - Since: 1.4
     */
    private var file_url: URL?
    
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
     * Flag for production MDX
     * - Version: 1.0
     * - Since: 1.4
     */
    public var has_production_mdx_file: Bool = false
    /**
     * The language driver id
     * - Version: 1.0
     * - Since: 1.4
     * > Note: This is very specific to dBase 7
     */
    public var language_driver_id: UInt8 = 0x00
    /**
     * The language driver name
     * - Version: 1.0
     * - Since: 1.4
     * > Note: This is very specific to dBase 7
     */
    public var language_driver_name: String = ""
    
    /**
     * This will initialize the DBF File with an empty DBF Table
     * - Parameters:
     *  - path: Required. The path to the DBF file
     * - Version: 1.0
     * - Since: 1.0
     * > Note: This constructor has been deprecated. Use DBFFile(contentsOf:) instead and pass in a URL to the file directly which makes file reading more accurate
     */
    @available(*, deprecated, message: "Usage of DBFFile(path:) is deprecated. Use DBFFile(contentsOf:) or DBFFile(contentsOf:, auto_read:, encoding:) instead.")
    init(path: String) {
        // initialize empty table
        self.filePath = path
        self.dbfTable = DBFTable()
        
        // try to adjust to the next release by inputting URL
        self.file_url = URL(filePath: path)
    }
    /**
     * Initializes the DBF file with an empty DBF table
     * - Parameters:
     *  - contentsOf: Required. The path to the DBF file
     * - Version: 1.0
     * - Since: 1.4
     */
    init(contentsOf: URL) {
        // initialize empty table
        self.file_url = contentsOf
        self.dbfTable = DBFTable()
    }
    /**
     * Initializes the DBF file with an empty DBF table with an option of automatically reading it and loading all data into memory
     * - Parameters:
     *  - contentsOf: Required. The path to the DBF file
     *  - auto_read: Required. If the file should be automatically read (this calls DBFFile.read automatically)
     *  - encoding: Required. The encoding to use
     * - Throws: An error on read
     * - Version: 1.0
     * - Since: 1.4
     */
    init(contentsOf: URL, auto_read: Bool = false, encoding: String.Encoding = .utf8) throws {
        // initialze empty table
        self.file_url = contentsOf
        self.dbfTable = DBFTable()
        
        // now call read
        try self.read(encoding: encoding)
    }
    
    /**
     * This will initialize the DBF File with a given table
     *
     * > Warning! This constructor will **not** allow you read a file. It is here for future development purposes
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
     * Gets the version of the DBF file but returns it as an enum
     * - Returns: The enum representation of the version or nil on failure
     * - Version: 1.0
     * - Since: 1.4
     */
    public func getDbaseVersion() -> DbaseVersion? {
        return .init(rawValue: self.dbfVersion)
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
     * - Version: 1.3
     * - Since: 1.0
     */
    public func read(encoding: String.Encoding = String.Encoding.utf8) throws {
        // make sure we have a valid path given
        if self.file_url == nil {
            throw DBFError.READ_ERROR("Cannot read DBF file because path is nil")
        }
        // also make sure path given is valid url
//        if URL(string: self.filePath!) == nil {
//            throw DBFError.READ_ERROR("Invalid file path given: \(self.filePath!)")
//        }
        // open the file
//        let buffer: Data = try Data(contentsOf: URL(string: self.filePath!)!)
        let buffer: Data = try Data(contentsOf: self.file_url!)
        // we should have at least 32 bytes
        if buffer.count < 32 {
            throw DBFError.READ_ERROR("Invalid DBF file")
        }
        // byte 0 should be version
        let version: UInt8 = buffer[0]
        self.dbfVersion = version
        // automatically switch over to dBase7 reading if the version is dBase 7
        if version == 0x04 {
            return try self.readDbase7(encoding: encoding)
        }
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
        let rec_size_data = buffer.subdata(in: 4..<8)
        let rec = rec_size_data.withUnsafeBytes { ptr in
          return Int(ptr.load(as: UInt32.self))
        }
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
        
        // use byte 10 and 11 for future comparison
        let one_record_bytes_data = buffer.subdata(in: 10..<12)
        let one_record_bytes = one_record_bytes_data.withUnsafeBytes { ptr in
          return Int(ptr.load(as: UInt16.self))
        }

        // it is perfectly safe to skip to byte 32 where the col info begins
        // keep on collecting col info until the terminator is reached
        var current_byte: Data.Index = 32
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
//            try self.dbfTable.addColumn(with: field_name, dataType: .init(rawValue: field_type)!, count: Int(field_len))
            self.dbfTable.addColumn(DBFTable.DBFColumn(columnType: .init(rawValue: field_type)!, name: field_name, count: Int(field_len)))
            bytec += 32
            current_byte = bytec
            
            // lets make sure current_byte is still valid
            if current_byte >= buffer.count {
                throw DBFError.READ_ERROR("Reached end of buffer while reading field names")
            }
        }
        // make sure expected record count matches what was written earlier
        if expected_record_count != one_record_bytes {
            throw DBFError.READ_ERROR("Byte 10 in dbf file (number of bytes in one record) does not match total number of bytes accross all fields")
        }
        // lock column add
        self.dbfTable.lockColumnAdding()
        // terminator reached, read records
        current_byte += 1

        var record_deleted: Bool = false

        // make sure that the last byte is the eof marker
        if buffer[buffer.count - 1] != 0x1A {
            throw DBFError.READ_ERROR("EOF marker not found!")
        }

        var rowSize = 1 // To include record delete / valid marker
        for col in self.dbfTable.getColumns() {
          rowSize += col.count
        }
        if (buffer.count - 1 - current_byte) % rowSize != 0 {
          throw DBFError.READ_ERROR("EOF marker is at an unexpected offset!")
        }

        while buffer[current_byte] != 0x1A {

          let recordData = buffer.subdata(in: current_byte ..< current_byte + rowSize)
          current_byte += rowSize

          var dataColumns: [Data] = []
          if (recordData[0] == 0x2A) {
            record_deleted = true
          } else if (recordData[0] == 0x20) {
            record_deleted = false
          } else {
            throw DBFError.READ_ERROR("Can't assert if the record is deleted")
          }

          var rowOffset = 1 // Skipping the record start marker
          for col in self.dbfTable.getColumns()  {
            dataColumns += [recordData.subdata(in: rowOffset ..< rowOffset + col.count)]
            rowOffset += col.count
          }

          var row: [String] = []
          for (col, data) in zip(self.dbfTable.getColumns(), dataColumns ){
            switch col.columnType {
            case .AUTOINCREMENT:
              fallthrough
            case .LONG:
              // the following was adapted from to convert [UInt8] to Int: https://stackoverflow.com/questions/32769929/convert-bytes-uint8-array-to-int-in-swift
              // we only have to record 4 bytes
              // now convert to int
              let value = data.withUnsafeBytes { ptr in
                return Int(ptr.load(as: UInt32.self))
              }
              row += [String(value)]
            case .DOUBLE:
              // the following was adapted from: https://stackoverflow.com/questions/31773367/convert-byte-array-to-double-in-swift
              let value = data.withUnsafeBytes { ptr in
                return Double(ptr.load(as: Double.self))
              }
              row += [String(value)]
            case .TIMESTAMP:
              // From https://www.dbase.com/Knowledgebase/INT/db7_file_fmt.htm
              // we can deduce it as follows:
              //   - Each timestamp is 8 bytes, containing two 'longs'
              //     (32 bit values) of unspecified endianess
              //   - The first integer is the date
              //   - The second is for the time specified as:
              //      hours * 3600000L + minutes * 60000L + Seconds * 1000L
              // That means that the time is milliseconds, covering a day,
              // without leap seconds (same behaviour as UNIX time).
              //
              // However, JDN starts with the day fraction being 0 at noon.
              // According to the documentation days is number of days
              // since 01/01/4713 BC, which coincide with the Julian period,
              // in the proleptic Julian(!!!) calendar.
              // However documentation does not state which calendar
              // the timestamps are referring to, and this matters since in the
              // proleptic Gregorian calendar the Julian period starts at
              // November 24, 4714 BC.
              // Note that this does not impact this reader which returns
              // a space separated string,

              let dayData = data.subdata(in: 0 ..< 4)
              let timeData = data.subdata(in: 4 ..< 8)

              let dayValue = dayData.withUnsafeBytes { ptr in
                return Int(ptr.load(as: UInt32.self))
              }
              let timeValue = timeData.withUnsafeBytes { ptr in
                return Int(ptr.load(as: UInt32.self))
              }

              row += ["\(dayValue) \(timeValue)"]
              break;
            default:
              guard let str = String(data: data, encoding: encoding) else {
                throw DBFError.READ_ERROR("Can't decode string")
              }
              row += [str]
            }
          }

//          try self.dbfTable.addRow(with: row, deleted: record_deleted)
            self.dbfTable.addRow(data: row, is_deleted: record_deleted)
        }
      
        // we read all data by this point
    }
    /**
     * Reads a dbase7 version file
     */
    public func readDbase7(encoding: String.Encoding = .utf8) throws {
        // the first few bytes are identical to normal dBase 3 file reading
        if self.file_url == nil {
            throw DBFError.READ_ERROR("Cannot read DBF file because path is nil")
        }
        // open the file
        let buffer: Data = try Data(contentsOf: self.file_url!)
        // we should have at least 32 bytes
        if buffer.count < 32 {
            throw DBFError.READ_ERROR("Invalid DBF file")
        }
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
        let rec_size_data = buffer.subdata(in: 4..<8)
        let rec = rec_size_data.withUnsafeBytes { ptr in
          return Int(ptr.load(as: UInt32.self))
        }
        self.numRecords = rec
        
        // bytes 8-9 should be number of bytes in header
        let header_bytes_data = buffer.subdata(in: 8..<10)
        let header_bytes = header_bytes_data.withUnsafeBytes { ptr in
            return Int(ptr.load(as: UInt16.self))
        }
        
        let one_record_bytes_data = buffer.subdata(in: 10..<12)
        let one_record_bytes = one_record_bytes_data.withUnsafeBytes { ptr in
          return Int(ptr.load(as: UInt16.self))
        }
        
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
        
        // production MDX stuff is byte 28
        if buffer[28] != 1 && buffer[28] != 0 {
            throw DBFError.READ_ERROR("Invalid MDX production flag: \(buffer[28])")
        }
        self.has_production_mdx_file = Int(buffer[28]) == 1
        
        // byte 29 is language driver id
        self.language_driver_id = buffer[29]
        
        // bytes 32-63 is language driver name
        self.language_driver_name = String(data: buffer.subdata(in: 32..<64), encoding: encoding) ?? ""
        
        // byte 68 is where the column stuff begins
        var current_byte: Data.Index = 68
        var bytec: Int = 68
        var expected_record_count: Int = 1
        while buffer[current_byte] != 0x0D {
            // in dbase 7 one column can be 32 chars in size
            let ending: Int = current_byte + 32
            // keep on collected field name until 0x00 (space) is reached
//            while buffer[current_byte] != 0x00 {
//                field_name += String(UnicodeScalar(buffer[current_byte]))
//                current_byte += 1
//            }
            
            let field_name: String = String(data: buffer.subdata(in: current_byte..<ending), encoding: .ascii)!.replacingOccurrences(of: "\0", with: "")
            
            // field type is right after the ending of the file name
            let field_type: Character = String(data: buffer.subdata(in: ending..<(ending + 1)), encoding: .ascii)!.first!
            // make sure character is valid
            
            if DBFTable.ColumnType.init(rawValue: field_type) == nil {
                throw DBFError.READ_ERROR("Unknown DBF data type \(field_type). Please make sure it is supported")
            }
            
            // get field length
            let field_len = buffer[ending + 1]
            expected_record_count += Int(field_len)
            
            // get decimal count
            let dec_count = buffer[ending + 2]
            
            // get production mdx flag
            let mdx_prod = buffer[ending + 5]
            // validate mdx flag
            if mdx_prod != 0x00 && mdx_prod != 0x01 {
                throw DBFError.READ_ERROR("Invalid production MDX field flag for column with name \(field_name): \(mdx_prod)")
            }
            
            // next autoincrement value
//            let auto_inc_bytes: [UInt8] = [buffer[current_byte + toType + 12], buffer[current_byte + toType + 13], buffer[current_byte + toType + 14], buffer[current_byte + toType + 15]]
            let auto_inc_bytes: [UInt8] = [
                buffer[ending + 8],
                buffer[ending + 9],
                buffer[ending + 10],
                buffer[ending + 11]
            ]
            
            // now convert to normal int
            let value = auto_inc_bytes.withUnsafeBytes { ptr in
              return Int(ptr.load(as: UInt32.self))
            }
            let auto_inc_value = Int(value)
            
            // we don't need anymore data than this
            self.dbfTable.addColumn(DBFTable.DBFColumn(columnType: .init(rawValue: field_type)!, name: field_name, count: Int(field_len), next_autoincrement_value: auto_inc_value, has_index_in_mdx_file: mdx_prod == 0x01, decimal_count: Int(dec_count)))
            bytec += 48 // in dbase7 one column is 48 bytes
            current_byte = bytec
            
            // lets make sure current_byte is still valid
            if current_byte >= buffer.count {
                throw DBFError.READ_ERROR("Reached end of buffer while reading field names")
            }
        }
        
        // lock column adding
        self.dbfTable.lockColumnAdding()
        
        // make sure expected record count matches what was written earlier
        if expected_record_count != one_record_bytes {
            throw DBFError.READ_ERROR("Byte 10 in dbf file (number of bytes in one record) does not match total number of bytes accross all fields")
        }
        
        // move past marker
        current_byte += 1
        
        // get the remaining bytes in the header
        // this is easy to compute
        // just take the expected header bytes and subtract it from what we already read
        let remaining_header_bytes: Data = buffer.subdata(in: current_byte..<header_bytes)
        
        // now we just build the field properties structure
        let field_properties = try FieldPropertiesStructure.decodeDBF(from: remaining_header_bytes, version: .DBASE7)
        
        // assign to dbf table
        self.dbfTable.field_properties = field_properties
        
        // now set the byte to when we begin reading the row data
        current_byte = header_bytes + 0 // should represent right at the moment we begin
        
        // now we read in the same way as dbase 3!
        var record_deleted: Bool = false

        // make sure that the last byte is the eof marker
        if buffer[buffer.count - 1] != 0x1A {
            throw DBFError.READ_ERROR("EOF marker not found!")
        }

        // validate that the row size is consistent
        var rowSize = 1 // To include record delete / valid marker
        for col in self.dbfTable.getColumns() {
          rowSize += col.count
        }
        // subtract one to exclude the eof marker
        if (buffer.count - 1 - current_byte) % rowSize != 0 {
          throw DBFError.READ_ERROR("Record sizes are not consistent")
        }

        while buffer[current_byte] != 0x1A {

          let recordData = buffer.subdata(in: current_byte ..< current_byte + rowSize)
          current_byte += rowSize

          var dataColumns: [Data] = []
          if (recordData[0] == 0x2A) {
            record_deleted = true
          } else if (recordData[0] == 0x20) {
            record_deleted = false
          } else {
            throw DBFError.READ_ERROR("Can't assert if the record is deleted")
          }

          var rowOffset = 1 // Skipping the record start marker
          for col in self.dbfTable.getColumns()  {
            dataColumns += [recordData.subdata(in: rowOffset ..< rowOffset + col.count)]
            rowOffset += col.count
          }

          var row: [String] = []
          for (col, data) in zip(self.dbfTable.getColumns(), dataColumns ){
            switch col.columnType {
            case .AUTOINCREMENT:
              fallthrough
            case .LONG:
              // the following was adapted from to convert [UInt8] to Int: https://stackoverflow.com/questions/32769929/convert-bytes-uint8-array-to-int-in-swift
              // we only have to record 4 bytes
              // now convert to int
              let value = data.withUnsafeBytes { ptr in
                return Int(ptr.load(as: UInt32.self))
              }
              row += [String(value)]
            case .DOUBLE:
              // the following was adapted from: https://stackoverflow.com/questions/31773367/convert-byte-array-to-double-in-swift
              let value = data.withUnsafeBytes { ptr in
                return Double(ptr.load(as: Double.self))
              }
              row += [String(value)]
            case .TIMESTAMP:
              // From https://www.dbase.com/Knowledgebase/INT/db7_file_fmt.htm
              // we can deduce it as follows:
              //   - Each timestamp is 8 bytes, containing two 'longs'
              //     (32 bit values) of unspecified endianess
              //   - The first integer is the date
              //   - The second is for the time specified as:
              //      hours * 3600000L + minutes * 60000L + Seconds * 1000L
              // That means that the time is milliseconds, covering a day,
              // without leap seconds (same behaviour as UNIX time).
              //
              // However, JDN starts with the day fraction being 0 at noon.
              // According to the documentation days is number of days
              // since 01/01/4713 BC, which coincide with the Julian period,
              // in the proleptic Julian(!!!) calendar.
              // However documentation does not state which calendar
              // the timestamps are referring to, and this matters since in the
              // proleptic Gregorian calendar the Julian period starts at
              // November 24, 4714 BC.
              // Note that this does not impact this reader which returns
              // a space separated string,

              let dayData = data.subdata(in: 0 ..< 4)
              let timeData = data.subdata(in: 4 ..< 8)

              let dayValue = dayData.withUnsafeBytes { ptr in
                return Int(ptr.load(as: UInt32.self))
              }
              let timeValue = timeData.withUnsafeBytes { ptr in
                return Int(ptr.load(as: UInt32.self))
              }

              row += ["\(dayValue) \(timeValue)"]
              break;
            case .NUMERIC:
                guard let str = String(data: data, encoding: encoding) else {
                  throw DBFError.READ_ERROR("Can't decode string")
                }
                  row += [str.replacingOccurrences(of: " ", with: "")] // strip spaces
            case .FLOAT:
                guard let str = String(data: data, encoding: encoding) else {
                  throw DBFError.READ_ERROR("Can't decode string")
                }
                  row += [str.replacingOccurrences(of: " ", with: "")] // strip spaces
            default:
              guard let str = String(data: data, encoding: encoding) else {
                throw DBFError.READ_ERROR("Can't decode string")
              }
                row += [str.replacingOccurrences(of: "\0", with: "")]
            }
          }

            self.dbfTable.addRow(data: row, is_deleted: record_deleted)
        }
    }
    /**
     * Reads a memo in a dbt file given the url. This already assumes that the dbf table has been generated (via the read function)
     * - Parameters:
     *  - file: Required. A URL to the DBT memo file. This **must** be in DBT format ONLY
     *  - index: Required. The index of the memo block derived from the value the record had
     *  - encoding: Required. Encoding used in the DBT file
     *  - block_size: Required. The size of each block. In dBase III, this will always be 1
     * - Returns: A string representing the data the memo field held
     * - Throws: An error upon read
     * - Version: 1.1
     * - Since: 1.2
     * > Note: By default, block\_size is set to 1 (each block is 512 bytes -- or as in dBase III format). HOWEVER, it is highly recommended to load all blocks into memory (via DBFFile.getDbtBlocks) and access the index of each memo from there rather than calling this function every single time you need to access a memo.
     */
    public func readMemo(file dbt: URL, index: Int, encoding: String.Encoding = .utf8, block_size: Int = 1) throws -> String {
        // validate block size
        if block_size <= 0 {
            throw DBFError.READ_ERROR("block_size cannot be <= 0")
        }
        // get data first
        let buffer: Data = try Data(contentsOf: dbt)
        var memo: String = ""
        
        // make sure that the size of the dbt is at least 1024 bytes (512 bytes for the header and the next 512+ for the blocks)
        if buffer.count < 1024 {
            throw DBFError.READ_ERROR("DBT file is too small")
        }
        
        let expected_size: Int = 512 * block_size
        
        // lets also make sure the buffer is divisible by 512
        if buffer.count % expected_size > 0 {
            throw DBFError.READ_ERROR("DBT file is not divisible by 512 (block size invalid). Please make sure each block size is exactly 512 bytes in size.")
        }
        
        // we can skip whatever is in the header, since that is irrelevant to the actual data being read
        
        let blockStart: Int = expected_size * index
        
        // lets make sure that blockStart is in bounds
        if blockStart >= buffer.count {
            // get length of full dbt file
            let dbt_len: Int = buffer.count / expected_size
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
        if blockStart + expected_size < index_eof {
            if buffer[index_eof + 1] != 0x1A {
                throw DBFError.READ_ERROR("Unterminated memo field! EOF marker not found")
            }
        }
        
        // get all data from blockStart to index_eof
//        let block: Data = buffer[blockStart..<index_eof]
        let block: Data = buffer.subdata(in: blockStart..<index_eof)
        
        memo = String(data: block, encoding: encoding) ?? ""
        
        return memo
    }
    /**
     * Extracts all the blocks from the memo file and returns them all
     * - Parameters:
     *  - file: Required. A URL to the DBT file
     *  - encoding: Required. Encoding used to decode the data
     *  - block_size: Required. The size of one block. Defaults to 1 (512 bytes)
     * - Returns: A dictionary, with the key being the index of the dbt block, and the value being the data it holds
     * - Throws: An error on read
     * - Version: 1.1
     * - Since: 1.3
     * > Note: This function is designed to specifically read dBase III memo (dbt) files. It can also read dBase IV with a custom block\_size being passed in. The data returned also includes the header block. But the only piece of data derived from the header is just the next available index for a DBT block. The rest of the elements are the real data that was held. Also note that any blocks which are stretched over to another block (because more space is needed for the data) **are merged** and the rest of the blocks are filled in a string that has no contents.
     */
    public func getDbtBlocks(file dbt: URL, encoding: String.Encoding = .utf8, block_size: Int = 1) throws -> Dictionary<Int, String> {
        // verify block size
        if block_size <= 0 {
            throw DBFError.READ_ERROR("Block size cannot be <= 0")
        }
        // retrieve data
        let data = try Data(contentsOf: dbt)
        
        // assert that there are at least 512 bytes in data
        if data.count < 512 {
            throw DBFError.READ_ERROR("DBT file is too small")
        }
        
        var dbt_blocks: Dictionary<Int, String> = Dictionary()
        
        // lets start by reading the header
        // we only ever need byte 0 in the header
        // the rest is garbage
        // we will also convert that byte into a real integer and then into a string
        let bytes: Data = Data([data[0], data[1], data[2], data[3]])
        let value = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        let actual_value: Int = Int(UInt32(littleEndian: value))
        dbt_blocks[0] = "\(actual_value)"
        
        let expected_bytes: Int = 512 * block_size
        
        // okay now make sure byte 511 is eof marker (0x1A)
        if data[expected_bytes - 1] != 0x1A {
            throw DBFError.READ_ERROR("DBT file is not properly terminated")
        }
        
        // now assert that the number of bytes data has is divisible by 512
        if data.count % expected_bytes > 0 {
            throw DBFError.READ_ERROR("DBT file is not a valid DBT file")
        }
        
        // read each block and add to dbt_blocks
        var block_index: Int = 1
        var next_available_index: Int = 1 // this is what we use for the dict
        while expected_bytes * block_index < data.count {
            let block_start: Int = expected_bytes * block_index
            
            // find eof marker
            let start_block: Data = data.subdata(in: block_start..<data.count)
            let eof_index: Int = start_block.firstIndex(of: 0x1A) ?? start_block.count
            
            // lets make sure eof_index was found
            if eof_index == start_block.count {
                throw DBFError.READ_ERROR("DBT file is not properly terminated")
            }
            
            // if the eof marker stretches beyond 512 bytes, expect one more eof
            if eof_index >= expected_bytes {
                if eof_index + 1 >= start_block.count {
                    throw DBFError.READ_ERROR("DBT file is not properly terminated")
                }
                if start_block[eof_index + 1] != 0x1A {
                    throw DBFError.READ_ERROR("DBT file is not properly terminated")
                }
                
                // we also need to figure out how to increment block_index in a way where we get to the next block
                let amount_increment: Int = Int(floor(Double(eof_index) / Double(expected_bytes)))
                block_index += amount_increment
            } else {
                // else increment block_index by 1
                block_index += 1
            }
            
            let block: Data = start_block.subdata(in: 0..<eof_index)
            
            let block_string: String = String(data: block, encoding: encoding) ?? ""
            
            // append to dbt_blocks
            dbt_blocks[next_available_index] = block_string.replacingOccurrences(of: "\0", with: "")
            
            next_available_index += 1
        }
        
        return dbt_blocks
    }
    /**
     * Works similarly to getDbtBlocks except blocks which stretches over to another block are not merged (in other words, every single block is returned)
     * - Parameters:
     *  - file: Required. The DBT file to read from
     *  - encoding: Required. The encoding to use for decoding data
     *  - block_size: Required. The size of each bock in the DBT file. Defaults to 1 (512 bytes)
     * - Returns: All the blocks
     * - Throws: An error on read
     * - Version: 1.1
     * - Since: 1.3
     */
    public func getDbtBlocksUnmerged(file dbt: URL, encoding: String.Encoding = .utf8, block_size: Int = 1) throws -> [String] {
        // validate block size
        if block_size <= 0 {
            throw DBFError.READ_ERROR("Block size cannot be <= 0")
        }
        // retrieve data
        let data = try Data(contentsOf: dbt)
        
        // assert that there are at least 512 bytes in data
        if data.count < 512 {
            throw DBFError.READ_ERROR("DBT file is too small")
        }
        
        var dbt_blocks: [String] = []
        
        let expected_size: Int = 512 * block_size
        
        // lets start by reading the header
        // we only ever need byte 0 in the header
        // the rest is garbage
        // we will also convert that byte into a real integer and then into a string
        dbt_blocks.append("\(Int(data[0]))")
        
        // okay now make sure byte 511 is eof marker (0x1A)
//        if data[511] != 0x1A {
        if data[expected_size - 1] != 0x1A {
            throw DBFError.READ_ERROR("DBT file is not properly terminated")
        }
        
        // now assert that the number of bytes data has is divisible by 512
//        if data.count % 512 > 0 {
        if data.count % expected_size > 0 {
            throw DBFError.READ_ERROR("DBT file is not a valid DBT file")
        }
        
        // read each block and add to dbt_blocks
        var block_index: Int = 1
        while expected_size * block_index < data.count {
            // we really won't be checking for the eof markers since we just want the blocks
            // and some blocks could stretch over another, therefore complicating things
            let block_start: Int = expected_size * block_index
            let block_end: Int = block_start + expected_size - 1
//            let block_data: Data = data[block_start..<block_end]
            let block_data: Data = data.subdata(in: block_start..<block_end)
            let block_string: String = String(data: block_data, encoding: encoding) ?? ""
            dbt_blocks.append(block_string)
            block_index += 1
        }
        
        return dbt_blocks
    }
    /**
     * Extracts general information in the header of a DBT file
     * - Parameters:
     *  - file: Required. A URL to the DBT file
     *  - version: Required. The type of version the DBT file is associated with
     * - Returns: The DBT file data
     * - Throws: An error on read
     * - Version: 1.0
     * - Since: 1.4
     */
    public func getDbtHeaderData(file dbt: URL, version: DbaseVersion) throws -> DBTFileData {
        // get data
        let data: Data = try Data(contentsOf: dbt)
        
        // check if data is at least 512 bytes in size
        if data.count < 512 {
            throw DBFError.READ_ERROR("DBT file too small")
        }
        
        // bytes 0-3 is next block
        // this is stored as uint32 (little endian)
        // so convert out of it
        let bytes: Data = Data([data[0], data[1], data[2], data[3]])
        let value = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        let actual_value: Int = Int(UInt32(littleEndian: value))
        
        // are we working with dbase 3?
        if version == .DBASE3 {
            // then there seriously isn't much to get
            // byte 16 is version number
            let version_dbt: UInt8 = data[16]
            // that's all the header info!
            
            return DBTFileData(version: version_dbt, next_append_index: actual_value, block_size: 1, block_length: 512)
        } else if version == .DBASE7 || version == .DBASE4_WITH_MEMO {
            // bytes 5-7 is size of blocks
//            let bytes_size: Data = Data([data[4], data[5], data[6], data[7]])
//            let value_size = bytes_size.withUnsafeBytes { $0.load(as: UInt32.self) }
//            let actual_value_size: Int = Int(UInt32(littleEndian: value_size))
            let actual_value_size: Int = Int(data[5]) | (Int(data[6]) << 8) | (Int(data[7]) << 16)
            
            // bytes 20-21 is block length
//            let block_length: Int = FieldPropertiesStructure.convertFromBytes(data[20], data[21])
            let block_length: Int = FieldPropertiesStructure.convertFromBytes16(data[20], data[21])
            
            return DBTFileData(version: nil, next_append_index: actual_value, block_size: actual_value_size, block_length: block_length)
        }
        
        throw DBFError.READ_ERROR("DBFFile.getDbtHeaderData can only extract data from dBase III, dBase IV, and dBase VII files.")
    }
}
