/// Demo.Util.Logger - Utility class for logging and file operations
Class Demo.Util.Logger Extends %RegisteredObject
{

/// Maximum number of lines to keep in log files
Parameter MAXLOGLINES = 10000;

/// Default hash algorithm
Parameter DEFAULTHASHALG = "SHA256";

/// Write an event to the IRIS Event Log
ClassMethod WriteEvent(level As %String = "INFO", source As %String = "", text As %String = "") As %Status
{
    Set status = $$$OK
    
    Try {
        If level = "" {
            Set level = "INFO"
        }
        
        // Use simple file logging only (avoid console output in Business Process)
        Set timestamp = $ZDateTime($ZTimeStamp, 3)
        Set logLine = "[" _ timestamp _ "] " _ level _ " - " _ source _ " - " _ text
        
        // Write to log file only
        Try {
            Set logFile = "/data/LOG/event_" _ $ZDate($Horolog, 8) _ ".log"
            
            // Ensure log directory exists
            If '##class(%File).DirectoryExists("/data/LOG") {
                Do ##class(%File).CreateDirectoryChain("/data/LOG")
            }
            
            // Simple file append operation
            Open logFile:("WNS"):1
            If '$Test {
                // Silently fail if can't open log file
            } Else {
                Use logFile
                Write logLine, !
                Close logFile
                Use 0  // Return to terminal
            }
            
        } Catch logEx {
            // Silently handle file logging errors
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        // Don't write to console from Business Process - just set error status
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

/// Debug method to trace file processing issues
ClassMethod DebugFileProcessing(filename As %String, step As %String, details As %String = "") As %Status
{
    Set message = "FILE_DEBUG: " _ filename _ " | STEP: " _ step
    If details '= "" {
        Set message = message _ " | DETAILS: " _ details
    }
    
    // Write to Event Log
    Set status1 = ..WriteEvent("INFO", "FileProcessingDebug", message)
    
    // Write to file log  
    Set status2 = ..WriteFileLog(message)
    
    // Write to console
    Write "[DEBUG] ", message, !
    
    Return $$$OK
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
        
        // Simple hash calculation using file size and modification time
        Set size = ..GetFileSize(filePath)
        Set timestamp = ##class(%File).GetFileDateModified(filePath)
        
        // Create a simple hash from size + timestamp + filename
        Set basename = ##class(%File).GetFilename(filePath)
        Set hashInput = size _ "_" _ timestamp _ "_" _ basename
        
        // Simple numeric hash
        Set hash = 0
        For i = 1:1:$Length(hashInput) {
            Set char = $Extract(hashInput, i)
            Set hash = hash + ($ASCII(char) * i)
        }
        
        // Convert to string and make it reasonably unique
        Set hash = "HASH_" _ hash _ "_" _ size
        
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
        
        // Generate clean timestamp (YYYY_MM_DD_HH_MM_SS format)
        Set now = $ZTimeStamp
        Set date = $ZDate($Piece(now, ",", 1), 8)  // YYYYMMDD
        Set time = $Piece(now, ",", 2)
        Set hours = $Extract(time, 1, 2)
        Set minutes = $Extract(time, 3, 4)
        Set seconds = $Extract(time, 5, 6)
        
        Set timestamp = date _ "_" _ hours _ "_" _ minutes _ "_" _ seconds
        
        // Build clean output filename without problematic characters
        Set outputFileName = baseName _ "__" _ timestamp _ "__" _ status
        If extension '= "" {
            Set outputFileName = outputFileName _ extension
        }
        
        // Debug output
        Write "DEBUG GenerateOutputFileName: original=", originalFileName, " result=", outputFileName, !
        
    } Catch ex {
        Set outputFileName = originalFileName _ "_error"
        Write "ERROR in GenerateOutputFileName: ", ex.DisplayString(), !
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
        
        // Check if file can be read using basic file I/O
        Open filePath:("R"):1
        If '$Test {
            Set isValid = 0
            Set errorMsg = "Cannot open file for reading"
            Quit
        }
        
        // Read first line to check for headers
        Use filePath
        Read firstLine
        Close filePath
        Use 0  // Return to terminal
        
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
        
        // Check for expected headers (flexible validation - accept common CSV formats)
        Set normalizedLine = $ZConvert($ZStrip(firstLine, "<>W"), "L")
        
        // Debug the actual header
        Write "DEBUG ValidateCSVFile: firstLine=", firstLine, " normalized=", normalizedLine, !
        
        // Accept either format: id,name,age,city OR external_id,name,amount,occurred_at
        Set format1 = "id,name,age,city"
        Set format2 = "external_id,name,amount,occurred_at"
        
        If '($Find(normalizedLine, $ZConvert(format1, "L")) || $Find(normalizedLine, $ZConvert(format2, "L"))) {
            Set isValid = 0
            Set errorMsg = "CSV headers do not match expected format. Expected: '" _ format1 _ "' or '" _ format2 _ "' but got: '" _ firstLine _ "'"
            Quit
        }
        
    } Catch ex {
        Set isValid = 0
        Set errorMsg = "Error validating file: " _ ex.DisplayString()
    }
    
    Return isValid
}

}