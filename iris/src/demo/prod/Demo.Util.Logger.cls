/// Demo.Util.Logger - Utility class for logging and file operations
Class Demo.Util.Logger Extends %RegisteredObject
{

/// Maximum number of lines to keep in log files
Parameter MAXLOGLINES = 10000;

/// Default hash algorithm
Parameter DEFAULTHASHALG = "SHA256";

/// Write an event to the IRIS Event Log
ClassMethod WriteEvent(level As %String, source As %String, text As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Validate level
        If '(level = "INFO" || level = "WARNING" || level = "ERROR" || level = "FATAL") {
            Set level = "INFO"
        }
        
        // Create event log entry
        Set event = ##class(Ens.Event.Log).%New()
        Set event.Type = level
        Set event.Source = source
        Set event.Text = text
        Set event.Time = $ZDateTime($ZTimeStamp, 3)
        
        Set status = event.%Save()
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Write a line to the daily log file
ClassMethod WriteFileLog(message As %String, logDir As %String = "/data/LOG") As %Status
{
    Set status = $$$OK
    
    Try {
        // Generate log filename with current date
        Set today = $ZDate($Horolog, 8)  // YYYYMMDD format
        Set logFile = logDir _ "/ingest_" _ today _ ".log"
        
        // Prepare log line with timestamp
        Set timestamp = $ZDateTime($ZTimeStamp, 3)  // ISO format
        Set logLine = timestamp _ " " _ message
        
        // Open file for append
        Set file = ##class(%File).%New(logFile)
        Do file.Open(logFile, "WA")  // Write Append mode
        
        // Write line
        Do file.WriteLine(logLine)
        Do file.Close()
        
        // Rotate log if it gets too large
        Do ..RotateLogIfNeeded(logFile)
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Calculate hash of a file
ClassMethod HashFile(filePath As %String, algorithm As %String = {..#DEFAULTHASHALG}) As %String
{
    Set hash = ""
    
    Try {
        // Validate file exists
        If '##class(%File).Exists(filePath) {
            Return ""
        }
        
        // Open file as binary stream
        Set stream = ##class(%FileCharacterStream).%New()
        Set status = stream.LinkToFile(filePath)
        If $$$ISERR(status) {
            Return ""
        }
        
        // Calculate hash based on algorithm
        If algorithm = "SHA256" {
            Set hash = ..HashStreamSHA256(stream)
        } ElseIf algorithm = "MD5" {
            Set hash = ..HashStreamMD5(stream)
        } Else {
            // Default to simple CRC
            Set hash = ..HashStreamCRC(stream)
        }
        
    } Catch ex {
        Set hash = ""
    }
    
    Return hash
}

/// Calculate SHA256 hash of a stream
ClassMethod HashStreamSHA256(stream As %Stream.Object) As %String
{
    Set hash = ""
    
    Try {
        // Use IRIS crypto functions
        Set hashObj = ##class(%System.Encryption).SHA256Hash()
        
        Do stream.Rewind()
        While 'stream.AtEnd {
            Set chunk = stream.Read(4096)  // Read in 4KB chunks
            Do hashObj.Update(chunk)
        }
        
        Set hash = hashObj.Final()
        Set hash = $System.Encryption.Base64Encode(hash)
        
    } Catch ex {
        Set hash = ""
    }
    
    Return hash
}

/// Calculate MD5 hash of a stream (simple implementation)
ClassMethod HashStreamMD5(stream As %Stream.Object) As %String
{
    Set hash = ""
    
    Try {
        // Use IRIS crypto functions for MD5
        Set hashObj = ##class(%System.Encryption).MD5Hash()
        
        Do stream.Rewind()
        While 'stream.AtEnd {
            Set chunk = stream.Read(4096)
            Do hashObj.Update(chunk)
        }
        
        Set hash = hashObj.Final()
        Set hash = $System.Encryption.Base64Encode(hash)
        
    } Catch ex {
        Set hash = ""
    }
    
    Return hash
}

/// Calculate simple CRC hash of a stream
ClassMethod HashStreamCRC(stream As %Stream.Object) As %String
{
    Set crc = 0
    
    Try {
        Do stream.Rewind()
        While 'stream.AtEnd {
            Set chunk = stream.Read(1024)
            For i=1:1:$Length(chunk) {
                Set crc = crc + $ASCII(chunk, i)
            }
        }
        
        // Convert to hex string
        Set hash = $ZHEX(crc)
        
    } Catch ex {
        Set hash = "0"
    }
    
    Return hash
}

/// Get current timestamp in ISO format
ClassMethod NowISO() As %String
{
    Return $ZDateTime($ZTimeStamp, 3)
}

/// Get file size in bytes
ClassMethod GetFileSize(filePath As %String) As %Integer
{
    Set size = 0
    
    Try {
        If ##class(%File).Exists(filePath) {
            Set size = ##class(%File).GetFileSize(filePath)
        }
    } Catch ex {
        Set size = 0
    }
    
    Return size
}

/// Rotate log file if it exceeds maximum lines
ClassMethod RotateLogIfNeeded(logFile As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Count lines in log file
        Set lineCount = 0
        Set file = ##class(%File).%New()
        If file.Open(logFile, "R") {
            While 'file.AtEnd {
                Do file.ReadLine()
                Set lineCount = lineCount + 1
            }
            Do file.Close()
        }
        
        // If too many lines, rotate
        If lineCount > ..#MAXLOGLINES {
            Set backupFile = logFile _ ".old"
            Set status = ##class(%File).Rename(logFile, backupFile)
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Check if file is a duplicate based on hash
ClassMethod IsDuplicateFile(filePath As %String, fileHash As %String) As %Boolean
{
    Set isDuplicate = 0
    
    Try {
        // Check in a simple global for processed files
        // In production, this should be a proper table
        Set global = "^Demo.ProcessedFiles"
        
        // Look for this hash
        If $Data(@global@(fileHash)) {
            Set isDuplicate = 1
        }
        
    } Catch ex {
        Set isDuplicate = 0
    }
    
    Return isDuplicate
}

/// Mark file as processed to prevent duplicates
ClassMethod MarkFileAsProcessed(fileName As %String, fileHash As %String, status As %String) As %Status
{
    Set result = $$$OK
    
    Try {
        Set global = "^Demo.ProcessedFiles"
        Set timestamp = ..NowISO()
        
        // Store file processing info
        Set @global@(fileHash) = fileName _ "^" _ status _ "^" _ timestamp
        
    } Catch ex {
        Set result = ex.AsStatus()
    }
    
    Return result
}

/// Generate output filename with timestamp and status
ClassMethod GenerateOutputFileName(originalFileName As %String, status As %String) As %String
{
    Set outputFileName = ""
    
    Try {
        // Extract name without extension
        Set dotPos = 0
        For i=$Length(originalFileName):-1:1 {
            If $Extract(originalFileName, i) = "." {
                Set dotPos = i
                Quit
            }
        }
        
        If dotPos > 0 {
            Set baseName = $Extract(originalFileName, 1, dotPos-1)
            Set extension = $Extract(originalFileName, dotPos)
        } Else {
            Set baseName = originalFileName
            Set extension = ""
        }
        
        // Generate timestamp
        Set timestamp = $ZDateTime($ZTimeStamp, 3)
        Set timestamp = $Translate(timestamp, ":T-", "___")
        
        // Build output filename
        Set outputFileName = baseName _ "__" _ timestamp _ "__" _ status _ extension
        
    } Catch ex {
        Set outputFileName = originalFileName _ "_error"
    }
    
    Return outputFileName
}

/// Validate CSV file format
ClassMethod ValidateCSVFile(filePath As %String, ByRef errorMsg As %String) As %Boolean
{
    Set isValid = 1
    Set errorMsg = ""
    
    Try {
        // Check file exists
        If '##class(%File).Exists(filePath) {
            Set isValid = 0
            Set errorMsg = "File does not exist"
            Quit
        }
        
        // Check file size
        Set size = ..GetFileSize(filePath)
        If size <= 0 {
            Set isValid = 0
            Set errorMsg = "File is empty"
            Quit
        }
        
        // Check if file can be read
        Set file = ##class(%File).%New()
        If 'file.Open(filePath, "R") {
            Set isValid = 0
            Set errorMsg = "Cannot open file for reading"
            Quit
        }
        
        // Read first line to check for headers
        Set firstLine = file.ReadLine()
        Do file.Close()
        
        If firstLine = "" {
            Set isValid = 0
            Set errorMsg = "File appears to be empty"
            Quit
        }
        
        // Basic CSV format validation
        If '$Find(firstLine, ",") {
            Set isValid = 0
            Set errorMsg = "File does not appear to be CSV format (no commas found)"
            Quit
        }
        
        // Check for expected headers
        Set expectedHeaders = "external_id,name,amount,occurred_at"
        Set normalizedLine = $ZConvert(firstLine, "L")
        Set normalizedExpected = $ZConvert(expectedHeaders, "L")
        
        If '$Find(normalizedLine, normalizedExpected) {
            Set isValid = 0
            Set errorMsg = "CSV headers do not match expected format: " _ expectedHeaders
            Quit
        }
        
    } Catch ex {
        Set isValid = 0
        Set errorMsg = "Error validating file: " _ ex.DisplayString()
    }
    
    Return isValid
}

}