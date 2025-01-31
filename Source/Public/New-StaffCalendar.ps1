<#
.SYNOPSIS
Creates a staff calendar for a specified year, either from a list of users with the same work hours or from a CSV file.

.DESCRIPTION
This function generates a staff calendar in Excel format for a given year.  It can accept a list of users with default work
hours or import users from a CSV file.  The resulting calendar includes workdays, user names, and their respective work
hours.  Various parameters allow customization of the Excel file, including the file name, worksheet title, and zoom level.

.PARAMETER year
Specifies the calendar year to create.

.PARAMETER users
Specifies the list of users to be added to the calendar.  This parameter is mandatory when using the "users" parameter set.

.PARAMETER defaultUserHours
Specifies the work hours to be used for all manually specified users. The default value is "8-5".
This parameter is in the "users" parameter set.

.PARAMETER csvPath
Specifies the CSV file path to import user data. The CSV requires a header row of "Name" and "WorkHours".
This parameter is mandatory when using the "csv" parameter set.

.PARAMETER excelFileName
Specifies the filename of the created Excel file. The default value is "$year Staff Schedule".

.PARAMETER worksheetTitleRow
Specifies the worksheet title string that will be followed by the month name. The default value is "Staff Calendar".

.PARAMETER firstColumnWidth
Specifies the width of the "A" column. The default value is 13.

.PARAMETER worksheetZoomLevel
Specifies the zoom level for each sheet. The default value is 100.

.EXAMPLE
PS C:\> New-StaffCalendar -year 1997 -users "Jack O", "Sam C", "Daniel J" -defaultUserHours "9-5"

Creates a staff calendar for the year 1997 with specified users and default work hours from 9 to 5.

.EXAMPLE
PS C:\> New-StaffCalendar -year 2266 -csvPath .\csv_example\staff.csv

Creates a staff calendar for the year 2266 using user data imported from the specified CSV file.

.NOTES
This function requires Excel to be installed on the system as it interacts with the Excel COM object to generate the calendar.

.LINK
https://github.com/bordwalk2000/StaffCalendar
#>

Function New-StaffCalendar {
    [CmdletBinding(
        DefaultParameterSetName = "users"
    )]
    param (
        # Calendar year to create
        [Parameter(
            Mandatory,
            HelpMessage = "Year you want calendar created for."
        )]
        [int]
        $year,

        # List of users to be added
        [Parameter(
            Mandatory,
            HelpMessage = "List of users to be added.",
            ParameterSetName = "users"
        )]
        [string[]]
        $users,

        # The work houses to be used for the users specified.
        [Parameter(
            HelpMessage = "The work hours to be used for all the manually specified users.",
            ParameterSetName = "users"
        )]
        [string]
        $defaultUserHours = "8:00-5:00",

        # List of users to be added
        [Parameter(
            Mandatory,
            HelpMessage = "CSV Path to get data.",
            ParameterSetName = "csv"
        )]
        [ValidateScript(
            {
                Test-Path -Path $_
            }
        )]
        [System.IO.FileInfo]
        $csvPath,

        # Excel file name
        [Parameter(
            HelpMessage = "Filename of created excel file."
        )]
        [string]
        $excelFileName = "$year Staff Schedule",

        # Worksheet title row
        [Parameter(
            HelpMessage = "Worksheet title string that will be followed by the month name."
        )]
        [string]
        $worksheetTitleRow = "Staff Calendar",

        # Column "A" Width
        [Parameter(
            HelpMessage = "The width of the of the 'A' column."
        )]
        [int]
        $firstColumnWidth = 13,

        # Worksheet Zoom Level
        [Parameter(
            HelpMessage = "Set the zoom level you would like for each sheet."
        )]
        [int]
        $worksheetZoomLevel = 100,

        # Specify location where the excel file is going to be saved
        [Parameter(
            HelpMessage = "Path Excel file will be saved to."
        )]
        [ValidateScript(
            {
                Test-Path -Path $_
            }
        )]
        [string]
        $saveLocation = $PWD
    )

    # Create userList object
    if ($PSCmdlet.ParameterSetName -eq "csv") {
        $userList = Import-Csv $csvPath
    }
    elseif ($PSCmdlet.ParameterSetName -eq "users") {
        # Define userList object
        $userList = [PSCustomObject]@()

        # Populate to userList from list of users
        foreach ($user in $users) {
            $userList += [PSCustomObject]@{
                Name      = $user;
                WorkHours = $defaultUserHours
            }
        }
    }

    try {
        # Creates new Excel application
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false # Set to true for testing
        $workbook = $excel.Workbooks.Add()
    }
    catch {
        $Message = "Unable to Create Excel Object.  Make sure Excel is installed on current computer.  $_"
        Write-Error -Message $Message -ErrorAction Stop
    }

    # Get the list of month names and abbreviated month names
    $monthNameList = (Get-Culture).DateTimeFormat.MonthNames
    $abbreviatedMonthNameList = (Get-Culture).DateTimeFormat.AbbreviatedMonthNames

    # Initialize an array to hold the custom objects
    $months = @()

    # Loop through the month names and create a custom object for each month
    for ($i = 0; $i -lt $monthNameList.Length; $i++) {
        if ($monthNameList[$i] -ne "") {
            $month = [PSCustomObject]@{
                MonthNumber     = $i + 1  # Month number (1-based index)
                MonthName       = $monthNameList[$i]
                AbbreviatedName = $AbbreviatedMonthNameList[$i]
            }
            $months += $month
        }
    }

    foreach ($month in $months) {
        # Define progress bar params
        $progressParams = @{
            Activity        = "Creating Calendar"
            Status          = "Processing $($month.MonthName)"
            PercentComplete = ((100 / 12) * $month.MonthNumber)
        }

        # Create progress bar
        Write-Progress @progressParams

        # Add new sheet
        $worksheet = $workbook.Worksheets.Add(
            [System.Reflection.Missing]::Value, $workbook.Worksheets.Item($workbook.Worksheets.Count)
        )

        # Rename new sheet to month abbreviated name
        $worksheet.Name = $month.AbbreviatedName

        # Set zoom level
        if ($worksheetZoomLevel -ne 100) {
            $excel.ActiveWindow.Zoom = $worksheetZoomLevel
        }

        # Set column widths
        $worksheet.Columns.Item("A").ColumnWidth = $firstColumnWidth
        $worksheet.Columns.Item("B").ColumnWidth = 11.5
        $worksheet.Columns.Item("C").ColumnWidth = 11.5
        $worksheet.Columns.Item("D").ColumnWidth = 11.5
        $worksheet.Columns.Item("E").ColumnWidth = 11.5
        $worksheet.Columns.Item("F").ColumnWidth = 11.5
        $worksheet.Columns.Item("G").ColumnWidth = 2

        # Calculate the first and last day of the month
        $firstDayOfMonth = Get-Date -Year $year -Month $month.MonthNumber -Day 1
        $lastDayOfMonth = $firstDayOfMonth.AddMonths(1).AddDays(-1)

        # Initialize an array to hold the workdays
        $workdays = @()

        # Loop through each day of the month
        $currentDay = $firstDayOfMonth
        while ($currentDay -le $lastDayOfMonth) {
            # Check if the current day is a weekday (Monday to Friday)
            if ($currentDay.DayOfWeek -ne 'Saturday' -and $currentDay.DayOfWeek -ne 'Sunday') {
                $workdays += $currentDay
            }
            # Move to the next day
            $currentDay = $currentDay.AddDays(1)
        }

        # Group the workdays by week
        $weeks = @()
        $currentWeek = @()
        $lastWeekNumber = $null

        foreach ($day in $workdays) {
            $weekNumber = [System.Globalization.CultureInfo]::CurrentCulture.Calendar.GetWeekOfYear(
                $day, [System.Globalization.CalendarWeekRule]::FirstDay, [System.DayOfWeek]::Monday
            )
            if ($weekNumber -ne $lastWeekNumber) {
                if ($currentWeek.Count -gt 0) {
                    $weeks += , @($currentWeek)
                    $currentWeek = @()
                }
                $lastWeekNumber = $weekNumber
            }
            $currentWeek += $day
        }

        if ($currentWeek.Count -gt 0) {
            $weeks += , @($currentWeek)
        }

        # Define title cell settings
        $worksheet.Cells.Item(1, 2).Value2 = "$worksheetTitleRow - $($month.MonthName)"
        $worksheet.Cells.Item(1, 2).Font.Size = 22
        $worksheet.Cells.Item(1, 2).Font.Bold = $true

        # Merge and center title cells (B through F)
        $range = $worksheet.Range("B1:F1")
        $range.Merge()
        $range.HorizontalAlignment = -4108  # Center horizontally (xlCenter)
        $range.VerticalAlignment = -4108    # Center vertically (xlCenter)

        # Write the weeks to the Excel worksheet starting at row 4
        $row = 4
        foreach ($week in $weeks) {
            # Define week name and date range
            $dateCellRange = $worksheet.Range("B$($row-1):F$($row)")

            # Set background color to RGB (231,230,230) or #E7E6E6
            $dateCellRange.Interior.Color = 15132391

            # Add borders to the range with xlContinuous
            $dateCellRange.Borders.LineStyle = 1

            # Insert users rows
            $userRowCount = $row + 1
            foreach ($user in $userList) {
                $worksheet.Cells.Item(($userRowCount), (1)) = $user.Name
                # Set borders around all users data cells
                $worksheet.Range(
                    $worksheet.Cells.Item($userRowCount, 1),
                    $worksheet.Cells.Item($userRowCount, 6)
                ).Borders.LineStyle = 1
                $worksheet.Cells.Item(($userRowCount++), (1)).Font.Bold = $true
            }

            # Date data starts at cell B
            $col = 2

            # Insert Day Data
            foreach ($day in $week) {
                # Move start of month cell to the correct location
                if (
                    # Check if it's the first week of the month
                    [bool](
                        Compare-Object -ReferenceObject $weeks[0] -DifferenceObject $week -ExcludeDifferent -IncludeEqual
                    ) -and (
                        #Check if it's the first workday of the month
                        $day -eq $week[0]
                    )
                ) {
                    # If both checks are true then move the starting cell over the day of the week -1.
                    $col = $col + $day.DayOfWeek.value__ - 1
                }
                # Set work day cell
                $weekDayCell = $worksheet.Cells.Item(($row - 1), $col)
                $weekDayCell.Value2 = $day.DayOfWeek.ToString()
                $weekDayCell.Font.Bold = $true
                $weekDayCell.HorizontalAlignment = -4108  # -4108 corresponds to center alignment

                # Set date cell
                $dateCell = $worksheet.Cells.Item($row, $col)
                $dateCell.Value2 = $day.ToString("yyyy-MM-dd")
                $dateCell.Font.Bold = $true
                $dateCell.HorizontalAlignment = -4108  # -4108 corresponds to center alignment

                # Add work hours for each user
                $hourRowCount = $row + 1
                foreach ($user in $userList) {
                    # Set hour cell
                    $hoursCell = $worksheet.Cells.Item($hourRowCount, $col)
                    $hoursCell.NumberFormat = "@"  # "@" symbol is the cell format code for text
                    $hoursCell.Value2 = $user.WorkHours

                    # Increase hour row count
                    $hourRowCount++
                }

                # Increase column count
                $col++
            }
            $row = $row + $userList.Count + 3
        }

        # Set Font for the Sheet
        $worksheet.UsedRange.Font.Name = "Calibri"
    }

    # Complete the progress bar
    Write-Progress -Completed -Activity "Creating Calendar"

    # Delete worksheet named Sheet1
    $workbook.Worksheets.Item("Sheet1").Delete()

    # Set Jan cell to tbe the active one
    $workbook.Worksheets.Item("Jan").Activate()

    # Define where the file wil be saved
    $excelFile = "$saveLocation\$excelFileName.xlsx"

    # Remove existing file
    Remove-Item -Path $excelFile -ErrorAction SilentlyContinue

    # Save the Excel file
    $workbook.SaveAs($excelFile)

    # Excel clean up
    $workbook.Close($false)
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    Write-Output "Excel file created: $excelFile"
}