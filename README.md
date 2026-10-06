# SnagToShareX

Extract the largest embedded PNG from each Snagit `.SNAG` file with `SnagToShareX.ps1`. The script accepts a single file or a directory of `.SNAG` files (not recursive).

## Requirements

- Windows PowerShell or PowerShell with `System.Drawing` available.
- Access to the source `.SNAG` files and permission to write to the destination.

## Usage

Run these commands in PowerShell from the directory containing the script:

```powershell
# Convert one capture
.\SnagToShareX.ps1 -InputPath 'C:\Captures\example.SNAG'

# Convert all .SNAG files directly inside a folder
.\SnagToShareX.ps1 -InputPath 'C:\Captures'

# Choose a different output folder
.\SnagToShareX.ps1 -InputPath 'C:\Captures' -OutputFolder 'C:\Exports\Screenshots'
```

By default, PNGs are saved under the current user's `Documents\ShareX\Screenshots` folder. Each file is placed in a `yyyy-MM` subfolder based on the source file's creation time and retains the source basename (for example, `example.SNAG` becomes `yyyy-MM\example.png`). Existing output files are skipped, not overwritten. The script prints paths for successfully written PNGs and warns when a capture cannot be converted.