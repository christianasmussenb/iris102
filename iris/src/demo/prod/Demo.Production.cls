/// Demo.Production - Main production configuration for iris102 CSV ingestion demo
Class Demo.Production Extends Ens.Production
{

/// Production XData definition
XData ProductionDefinition
{
<Production Name="Demo.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>CSV File Ingestion Production for iris102 demo</Description>
  <ActorPoolSize>2</ActorPoolSize>
  
  <!-- File Service to monitor CSV files -->
  <Item Name="FileService" Category="" ClassName="Demo.FileService" 
        PoolSize="1" Enabled="true" Foreground="false" Comment="" 
        LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/data/IN</Setting>
    <Setting Target="Adapter" Name="FileSpec">*.csv</Setting>
    <Setting Target="Adapter" Name="Charset">UTF-8</Setting>
    <Setting Target="Adapter" Name="DeleteFromServer">1</Setting>
    <Setting Target="Adapter" Name="ArchivePath">/data/WIP</Setting>
    <Setting Target="Adapter" Name="WorkPath">/data/WIP</Setting>
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
  </Item>
  
  <!-- Business Process to handle CSV parsing and orchestration -->
  <Item Name="FileProcessor" Category="" ClassName="Demo.Process" 
        PoolSize="2" Enabled="true" Foreground="false" Comment="" 
        LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="InactivityTimeout">120</Setting>
  </Item>
  
    <!-- Test Simple Business Process removed during cleanup -->
  
  <!-- MySQL Operation -->
  <Item Name="MySQLOperation" Category="" ClassName="Demo.MySQL.Operation" 
        PoolSize="1" Enabled="true" Foreground="false" Comment="" 
        LogTraceEvents="true" Schedule="">
        <Setting Target="Adapter" Name="DSN">MySQL-Demo</Setting>
        <Setting Target="Adapter" Name="Credentials">MySQL-Demo-Credentials</Setting>
    <Setting Target="Host" Name="RetryCount">3</Setting>
    <Setting Target="Host" Name="RetryInterval">2</Setting>
  </Item>
  
  <!-- PostgreSQL Operation -->
  <Item Name="PostgreSQLOperation" Category="" ClassName="Demo.Postgres.Operation" 
        PoolSize="1" Enabled="true" Foreground="false" Comment="" 
        LogTraceEvents="true" Schedule="">
        <Setting Target="Adapter" Name="DSN">PostgreSQL-Demo</Setting>
        <Setting Target="Adapter" Name="Credentials">PostgreSQL-Demo-Credentials</Setting>
    <Setting Target="Host" Name="RetryCount">3</Setting>
    <Setting Target="Host" Name="RetryInterval">2</Setting>
  </Item>
  
</Production>
}

/// Initialize production settings from environment variables
ClassMethod OnStart(pTimeStarted As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Log production startup
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Production", "Production starting up...")
        Do ##class(Demo.Util.Logger).WriteFileLog("STARTUP Production Demo.Production starting")
        
        // Initialize database credentials from environment
        Do ..InitializeCredentials()
        
        // Initialize file paths from environment
        Do ..InitializeFilePaths()
        
        // Initialize database connections
        Do ..InitializeDatabaseConnections()
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Production", "Production startup completed successfully")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Production", "Production startup failed: " _ ex.DisplayString())
    }
    
    Return status
}

/// Initialize database credentials from environment variables
ClassMethod InitializeCredentials() As %Status
{
    Set status = $$$OK
    
    Try {
        // MySQL credentials
        Set mysqlUser = $System.Util.GetEnviron("MYSQL_USER", "demo")
        Set mysqlPassword = $System.Util.GetEnviron("MYSQL_PASSWORD", "demo_pass")
        
        // Create or update MySQL credentials
        Set cred = ##class(Ens.Config.Credentials).%New()
        Set cred.SystemName = "MySQL-Demo-Credentials"
        Set cred.Username = mysqlUser
        Set cred.Password = mysqlPassword
        Set status = cred.%Save()
        
        // PostgreSQL credentials
        Set pgUser = $System.Util.GetEnviron("PG_USER", "demo")
        Set pgPassword = $System.Util.GetEnviron("PG_PASSWORD", "demo_pass")
        
        // Create or update PostgreSQL credentials
        Set cred = ##class(Ens.Config.Credentials).%New()
        Set cred.SystemName = "PostgreSQL-Demo-Credentials"
        Set cred.Username = pgUser
        Set cred.Password = pgPassword
        Set status = cred.%Save()
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Production", "Database credentials initialized")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Production", "Failed to initialize credentials: " _ ex.DisplayString())
    }
    
    Return status
}

/// Initialize file paths from environment variables
ClassMethod InitializeFilePaths() As %Status
{
    Set status = $$$OK
    
    Try {
        // Get paths from environment
        Set inDir = $System.Util.GetEnviron("IN_DIR", "/data/IN")
        Set outDir = $System.Util.GetEnviron("OUT_DIR", "/data/OUT")
        Set logDir = $System.Util.GetEnviron("LOG_DIR", "/data/LOG")
        
        // Create directories if they don't exist
        If '##class(%File).DirectoryExists(inDir) {
            Do ##class(%File).CreateDirectoryChain(inDir)
        }
        If '##class(%File).DirectoryExists(outDir) {
            Do ##class(%File).CreateDirectoryChain(outDir)
        }
        If '##class(%File).DirectoryExists(logDir) {
            Do ##class(%File).CreateDirectoryChain(logDir)
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Production", "File paths initialized: IN=" _ inDir _ ", OUT=" _ outDir _ ", LOG=" _ logDir)
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Production", "Failed to initialize file paths: " _ ex.DisplayString())
    }
    
    Return status
}

/// Initialize database connections
ClassMethod InitializeDatabaseConnections() As %Status
{
    Set status = $$$OK
    
    Try {
        // Test MySQL connection
        Set mysqlHost = $System.Util.GetEnviron("MYSQL_HOST", "mysql")
        Set mysqlDB = $System.Util.GetEnviron("MYSQL_DB", "demo")
        Set mysqlPort = $System.Util.GetEnviron("MYSQL_PORT", "3306")
        
        Set mysqlJDBCURL = "jdbc:mysql://" _ mysqlHost _ ":" _ mysqlPort _ "/" _ mysqlDB _ "?useSSL=false&allowPublicKeyRetrieval=true"
        
        // Test PostgreSQL connection  
        Set pgHost = $System.Util.GetEnviron("PG_HOST", "postgres")
        Set pgDB = $System.Util.GetEnviron("PG_DB", "demo")
        Set pgPort = $System.Util.GetEnviron("PG_PORT", "5432")
        Set pgSSLMode = $System.Util.GetEnviron("PG_SSLMODE", "disable")
        
        Set pgJDBCURL = "jdbc:postgresql://" _ pgHost _ ":" _ pgPort _ "/" _ pgDB _ "?sslmode=" _ pgSSLMode
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Production", "Database connections configured - MySQL: " _ mysqlJDBCURL _ ", PostgreSQL: " _ pgJDBCURL)
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Production", "Failed to initialize database connections: " _ ex.DisplayString())
    }
    
    Return status
}

/// Production shutdown handler
ClassMethod OnStop(pTimeStarted As %String, pTimeStoppedLocal As %Boolean) As %Status
{
    Set status = $$$OK
    
    Try {
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Production", "Production shutting down...")
        Do ##class(Demo.Util.Logger).WriteFileLog("SHUTDOWN Production Demo.Production stopping")
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Get production settings summary for monitoring
ClassMethod GetProductionStatus() As %String
{
    Set summary = ""
    
    Try {
        Set summary = summary _ "Production: Demo.Production" _ $C(13,10)
        Set summary = summary _ "Status: " _ ##class(Ens.Director).GetProductionStatus() _ $C(13,10)
        Set summary = summary _ "Start Time: " _ ##class(Ens.Director).GetProductionStartTime() _ $C(13,10)
        Set summary = summary _ "Environment:" _ $C(13,10)
        Set summary = summary _ "  - IN_DIR: " _ $System.Util.GetEnviron("IN_DIR", "/data/IN") _ $C(13,10)
        Set summary = summary _ "  - OUT_DIR: " _ $System.Util.GetEnviron("OUT_DIR", "/data/OUT") _ $C(13,10)
        Set summary = summary _ "  - LOG_DIR: " _ $System.Util.GetEnviron("LOG_DIR", "/data/LOG") _ $C(13,10)
        Set summary = summary _ "  - MYSQL_HOST: " _ $System.Util.GetEnviron("MYSQL_HOST", "mysql") _ $C(13,10)
        Set summary = summary _ "  - PG_HOST: " _ $System.Util.GetEnviron("PG_HOST", "postgres") _ $C(13,10)
        
    } Catch ex {
        Set summary = "Error getting production status: " _ ex.DisplayString()
    }
    
    Return summary
}

}