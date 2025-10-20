Class iris.Installer.new Extends %RegisteredObject
{

/// Main installation method
ClassMethod Run() As %Status
{
    Set status = $$$OK
    
    Try {
        Write !,"=============================================================================",!
        Write "  IRIS 102 Demo - Sprint 5 Installation (JDBC)",!
        Write "  Fecha: 20 Octubre 2025",!
        Write "=============================================================================",!,!
        
        // Step 1: Import all source files
        Set status = ..ImportSources()
        If $$$ISERR(status) Quit
        
        // Step 2: Compile all classes
        Set status = ..CompileAll()
        If $$$ISERR(status) Quit
        
        // Step 3: Configure Java Gateway for JDBC
        Set status = ..SetupJavaGateway()
        If $$$ISERR(status) Quit
        
        // Step 4: Test JDBC connectivity
        Set status = ..TestJDBCConnectivity()
        If $$$ISERR(status) Quit
        
        // Step 5: Setup and start Production
        Set status = ..SetupProduction()
        If $$$ISERR(status) Quit
        
        Write !,"=============================================================================",!
        Write "  Installation completed successfully!",!
        Write "=============================================================================",!,!
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "Installation failed: ",!
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

/// Import all source files from /opt/irisapp/src
ClassMethod ImportSources() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Step 1: Importing source files from /opt/irisapp/src...",!
        
        // Import all .cls files recursively
        Set status = $system.OBJ.ImportDir("/opt/irisapp/src", "*.cls", "ckr", .errors, 1)
        If $$$ISERR(status) {
            Write "ERROR importing .cls files:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        // Import all .bpl files recursively (if any)
        Set status = $system.OBJ.ImportDir("/opt/irisapp/src", "*.bpl", "ckr", .errors, 1)
        If $$$ISERR(status) {
            Write "ERROR importing .bpl files:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        Write "  ✓ Source files imported successfully",!,!
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "EXCEPTION in ImportSources:",!
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

/// Compile all imported classes
ClassMethod CompileAll() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Step 2: Compiling all classes...",!
        
        Set status = $system.OBJ.CompileAll("ckr")
        If $$$ISERR(status) {
            Write "ERROR compiling classes:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        Write "  ✓ All classes compiled successfully",!,!
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "EXCEPTION in CompileAll:",!
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

/// Configure Java Gateway for JDBC connections
ClassMethod SetupJavaGateway() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Step 3: Configuring Java Gateway for JDBC...",!
        
        // Define Java Gateway service name
        Set gatewayName = "JavaGateway"
        
        // Check if Java Gateway already exists
        If ##class(%Library.EnsembleMgr).IsGatewayDefined(gatewayName) {
            Write "  - Java Gateway '"_gatewayName_"' already exists",!
        } Else {
            Write "  - Creating Java Gateway '"_gatewayName_"'...",!
            
            // Create Java Gateway configuration
            Set gateway = ##class(%Net.Remote.Service).%New()
            Set gateway.Name = gatewayName
            Set gateway.Type = 1  // Java Gateway
            Set gateway.Server = "127.0.0.1"
            Set gateway.Port = 55556
            Set gateway.HeapSize = 512  // 512 MB
            
            // Set classpath for JDBC drivers
            Set gateway.ClassPath = "/opt/irisapp/jdbc/mysql-connector-j-8.0.33.jar:/opt/irisapp/jdbc/postgresql-42.6.0.jar"
            
            // Save configuration
            Set status = gateway.%Save()
            If $$$ISERR(status) {
                Write "ERROR saving Java Gateway configuration:",!
                Do $System.Status.DisplayError(status)
                Quit
            }
            
            Write "  ✓ Java Gateway configured successfully",!
        }
        
        // Start the Java Gateway
        Write "  - Starting Java Gateway...",!
        Set status = ##class(%Net.Remote.Service).OpenGateway(gatewayName)
        If $$$ISERR(status) {
            Write "WARNING: Could not start Java Gateway:",!
            Do $System.Status.DisplayError(status)
            Write "  (Gateway will be started automatically when needed)",!
        } Else {
            Write "  ✓ Java Gateway started successfully",!
        }
        
        Write !
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "EXCEPTION in SetupJavaGateway:",!
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

/// Test JDBC connectivity to MySQL and PostgreSQL
ClassMethod TestJDBCConnectivity() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Step 4: Testing JDBC connectivity...",!
        
        // Create Java Gateway connection
        Set gateway = ##class(%Net.Remote.Gateway).%New()
        Set status = gateway.%Connect("127.0.0.1", 55556, $namespace)
        If $$$ISERR(status) {
            Write "WARNING: Cannot connect to Java Gateway:",!
            Do $System.Status.DisplayError(status)
            Write "  (Tests will be skipped, connectivity will be validated during runtime)",!
            Set status = $$$OK  // Don't fail installation
            Quit
        }
        
        Write "  ✓ Java Gateway connection established",!
        
        // Test MySQL JDBC Driver
        Write "  - Testing MySQL JDBC driver...",!
        Try {
            Set class = gateway.%New("java.lang.Class")
            Do class.forName("com.mysql.cj.jdbc.Driver")
            Write "    ✓ MySQL JDBC driver loaded successfully",!
        } Catch ex {
            Write "    WARNING: Could not load MySQL JDBC driver",!
        }
        
        // Test PostgreSQL JDBC Driver
        Write "  - Testing PostgreSQL JDBC driver...",!
        Try {
            Set class = gateway.%New("java.lang.Class")
            Do class.forName("org.postgresql.Driver")
            Write "    ✓ PostgreSQL JDBC driver loaded successfully",!
        } Catch ex {
            Write "    WARNING: Could not load PostgreSQL JDBC driver",!
        }
        
        // Disconnect gateway
        Do gateway.%Disconnect()
        
        Write !
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "EXCEPTION in TestJDBCConnectivity:",!
        Do $System.Status.DisplayError(status)
        // Don't fail installation on connectivity tests
        Set status = $$$OK
    }
    
    Return status
}

/// Setup and configure the Production
ClassMethod SetupProduction() As %Status
{
    Set status = $$$OK
    
    Try {
        Write "Step 5: Setting up Production...",!
        
        // Check if Production class exists
        If '##class(%Dictionary.ClassDefinition).%ExistsId("Demo.Production") {
            Write "WARNING: Demo.Production class not found",!
            Write "  Make sure the Production class is in /opt/irisapp/src",!
            Quit
        }
        
        // Start the Production
        Write "  - Starting Production 'Demo.Production'...",!
        Set status = ##class(Ens.Director).StartProduction("Demo.Production")
        If $$$ISERR(status) {
            Write "ERROR starting Production:",!
            Do $System.Status.DisplayError(status)
            Quit
        }
        
        Write "  ✓ Production started successfully",!,!
        
        // Display Production status
        Set running = ##class(Ens.Director).IsProductionRunning()
        If running {
            Write "  Production Status: RUNNING ✓",!
            Set production = ##class(Ens.Director).GetActiveProductionName()
            Write "  Active Production: "_production,!
        } Else {
            Write "  Production Status: STOPPED",!
        }
        
        Write !
        
    } Catch ex {
        Set status = ex.AsStatus()
        Write "EXCEPTION in SetupProduction:",!
        Do $System.Status.DisplayError(status)
    }
    
    Return status
}

}
