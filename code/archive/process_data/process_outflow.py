import pandas as pd
import os

path = "/proj/pbolken/climate/"
outcomes = f"{path}Haru/data/outcomes/"
migration = outcomes + "migration/"
df_list = []
pd.set_option('display.max_columns', None)
pd.set_option('display.width', None)

################################################################################
# Years 1990 to 1991
def parse_line(line):
      tokens = line.split()
    
      # Check if this is a first line in the block (with 'Total Migrati')
      if "Total" in line and "Migr" in line:
            origin_state = tokens[0]
            origin_county = tokens[1]
            # Everything from token 2 to second-last is part of description
            description_tokens = tokens[2:-3]
            returns = tokens[-2]
            exemptions = tokens[-1]
            description = " ".join(description_tokens)
            
      else:  # This is the last line (non-migrants line)
            origin_state = tokens[0]
            origin_county = tokens[1]
            description_tokens = tokens[2:-2]
            returns = tokens[-2]
            exemptions = tokens[-1]
            description = " ".join(description_tokens)

      return {
            "origin_state": origin_state,
            "origin_county": origin_county,
            "description": description,
            "returns": int(returns.replace(",", "")),
            "exemptions": int(exemptions.replace(",", ""))
      }


for year in range(1990, 1992):
      directory = f"{migration}{year}to{year+1}CountyMigration/{year}to{year+1}CountyMigrationOutflow"
      all_files = [f for f in os.listdir(directory) if f.endswith(".txt")]
      
      for file in all_files:
            print(file)
            file_path = os.path.join(directory, file)
            extracted_rows = []

            with open(file_path, "r") as file:
                  block = []
                  for line in file:
                        # If it's the start of a block (e.g. starts with two digits)
                        if line[:2].isdigit() and "Total" in line:
                              block = [line.rstrip()]
                        elif "County Non-Migrants" in line:
                              block.append(line.rstrip())
                              extracted_rows.extend(block)
                              block = []

            # Convert to DataFrame with raw lines
            df = pd.DataFrame(extracted_rows, columns=["raw_line"])
            parsed = df["raw_line"].apply(parse_line)
            df = pd.DataFrame(parsed.tolist())
            df["year"] = year
            print(df)
            
            df_list.append(df)

################################################################################
# Year 1992 and 1994
for year in [1992, 1994]:
      directory = f"{migration}{year}to{year+1}CountyMigration/{year}to{year+1}CountyMigrationOutflow"
      all_files = [f for f in os.listdir(directory) if f.endswith(".xls")]
      
      for file in all_files:
            print(file)
            file_path = os.path.join(directory, file)

            df = pd.read_excel(file_path, skiprows=8, dtype=str, usecols=range(9))
            df.columns = [
                  "origin_state", "origin_county", "dest_state", "dest_county",
                  "state_abbr", "description", "returns", "exemptions", "agg_income"
            ]

            # Filter conditions
            is_total_migration = df["dest_state"].str.strip().isin(["XX", "FR"])
            is_non_migrant = df["description"].str.contains("Non-Mig", case=False, na=False)

            # Apply filters
            filtered_df1 = df[is_total_migration]
            filtered_df2 = df[is_non_migrant]

            # Sum up migrants
            filtered_df1[["returns", "exemptions", "agg_income"]] = (
                  filtered_df1[["returns", "exemptions", "agg_income"]]
                  .replace({",": ""}, regex=True)  # remove commas
                  .apply(pd.to_numeric, errors="coerce")
            )

            # Group by and sum
            filtered_df1 = (
                  filtered_df1
                  .groupby(["origin_state", "origin_county"], as_index=False)[["returns", "exemptions", "agg_income"]]
                  .sum()
            )
            filtered_df1["description"] = "Total Migrants"
            df = pd.concat([filtered_df1, filtered_df2], ignore_index=True)
            df = df[["origin_state", "origin_county", "description", "returns", "exemptions", "agg_income"]]

            # Add the year column
            df["year"] = year
            print(df)
            
            df_list.append(df)



################################################################################
# Years 1993 to 2003 (except 1994)
for year in range(1993, 2004):
      if year != 1994:
            directory = f"{migration}{year}to{year+1}CountyMigration/{year}to{year+1}CountyMigrationOutflow"
            all_files = [f for f in os.listdir(directory) if f.endswith(".xls")]
            
            for file in all_files:
                  print(file)
                  file_path = os.path.join(directory, file)

                  df = pd.read_excel(file_path, skiprows=8, dtype=str, usecols=range(9))
                  df.columns = [
                        "origin_state", "origin_county", "dest_state", "dest_county",
                        "state_abbr", "description", "returns", "exemptions", "agg_income"
                  ]

                  # Strip leading/trailing spaces from description
                  df["description"] = df["description"].str.strip()

                  # Filter conditions
                  is_total_migration = (
                        df["description"].str.contains("Tot Mig-US & For", case=False) #1995-2003
                  )
                  has_total_migration = (
                        df["description"].str.contains("Total Migrant", case=False) #1993
                  )
                  is_non_migrant = (
                        df["description"].str.contains("Non-Mig", case=False)
                  )

                  # Apply filters
                  filtered_df = df[is_total_migration | is_non_migrant | has_total_migration]
                  filtered_df = filtered_df[["origin_state", "origin_county", "description", "returns", "exemptions", "agg_income"]]

                  # Add the year column
                  filtered_df["year"] = year
                  print(filtered_df)
                  
                  df_list.append(filtered_df)

################################################################################
# Years 2004 to 2010

# Define the column widths
colspecs = [
    (0, 2),   # FIPS State Code for Destination
    (3, 6),   # FIPS County Code for Destination
    (7, 9),   # FIPS State Code for Origin
    (10, 13), # FIPS County Code for Origin
    (14, 16), # 2-Character State Abbreviation
    (17, 49), # County Name
    (50, 59), # Number of Returns
    (59, 70), # Number of Exemptions
    (70, 82), # Aggregate Adjusted Gross Income
    (82, 91)  # Median Adjusted Gross Income
]

# Define the column names
colnames = [
    'origin_state', 'origin_county', 
    'dest_state', 'dest_county', 
    'state_abbr', 'description', 
    'returns', 'exemptions', 'agg_income', 'med_income'
]

for year in range(2004, 2011):
      year_str = f"{year % 100:02d}"
      year_str_1 = f"{(year+1) % 100:02d}"

      dir = f"{migration}county{year_str}{year_str_1}/"
      if year == 2004: file = f"countyout{year_str}{year_str_1}us1.dat"
      elif year in range(2005,2007): file = f"countyout{year_str}{year_str_1}.dat"
      elif year == 2007: file = f"co{year_str}{year_str_1}us.dat"
      elif year >= 2008: file = f"countyoutflow{year_str}{year_str_1}.dat"

      df = pd.read_fwf(open(dir + file, errors='ignore'), dtype=str, colspecs=colspecs, names=colnames)
      df = df[df['description'].str.contains('Tot Mig-US & For|Non-migrants', case=False, na=False)]


      df = df[["origin_state", "origin_county", "description", "returns", "exemptions", "agg_income"]]
      df["year"] = year
      print(df)
      
      df_list.append(df)

################################################################################
# Years 2011 to 2021

for year in range(2011, 2022):
      year_str = f"{year % 100:02d}"
      year_str_1 = f"{(year+1) % 100:02d}"

      file = f"{migration}countyoutflow{year_str}{year_str_1}.csv"

      df = pd.read_csv(open(file, errors="ignore"), dtype=str)
      df.columns = [
                  "origin_state", "origin_county", "dest_state", "dest_county",
                  "state_abbr", "description", "returns", "exemptions", "agg_income"
      ]
      df = df[df['description'].str.contains('Total Migration-US and Foreign|Non-migrants', case=False, na=False)]
      df = df[["origin_state", "origin_county", "description", "returns", "exemptions", "agg_income"]]
      df["year"] = year
      print(df)
      
      df_list.append(df)

################################################################################
# Append all DataFrames together
final_df = pd.concat(df_list, ignore_index=True)


for col in ["returns", "exemptions", "agg_income"]:
    was_missing = final_df[col].isna()
    converted = pd.to_numeric(final_df[col], errors="coerce").astype('Int64')
    final_df = final_df[was_missing | converted.notna()].copy()
    final_df[col] = converted[was_missing | converted.notna()]

print(final_df)

# final_df["returns"] = final_df["returns"].astype("Int64")
# final_df['exemptions'] = final_df['exemptions'].astype('Int64')
# final_df['agg_income'] = final_df['agg_income'].astype('Int64')
final_df.to_stata(f"{outcomes}migrationout_1990_2022.dta", write_index=False)
print(f"Migration data saved to {outcomes}migration_1990_2022.dta")