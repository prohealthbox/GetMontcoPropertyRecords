# GetMontcoPropertyRecords
Intelligently derives the Parcel ID's from the Montgomery County, PA Property Records database
and stores them, along with high-level overview information in a MySQL Database. As of 10/30/2015, this
is approximately 300,000 records.

The second step is to populate with greater detail each of the Parcel ID's. This is done by parsing information
on the Profile, Residential, Assessment History, and Sales tabs.

## Execution
### Step One - Collect Parcel ID's
This step uses a recursive query to select the complete set of parcel id's (verified) with the minimum number of
queries (or at least close to the minimum).

The following command will sequentially run through municipalities 01 through 67 to retrieve Parcel IDs.

```
$ ruby sequencer.rb
```

After this completes (less than 30 minutes) (/needs validation/), the properties table wil be populated with
almost 300,000 records, one per parcel.

### Step Two
The next step is to take each unprocessed parcel and complete the remaining documentation regarding it, extracting 
information from a number of pages into four tables, each with parcel_id as the primary key (or part of it).

The following command will grab the detail information for the unprocessed parcels.

```
$ ruby get_details.rb
```

Note this is prone to error (most likely on the server side). When observed, it will disconnect and restart.
Execution time is about 1/2 second to 1 second per property record.
When it fails, it is important to re-run the get_details.rb script to ensure all the data was captured. 

The method it uses to determine remaining parcels is to look at the municipality field in properties. If it is NULL,
it is assumed that this parcel has not been processed.

To process an individual parcel, regardless if it has been processed, execute the following.

```
$ ruby get_details.rb <parcel id>
```

Where parcel_id is the 12-digit parcel number.

The next execution of get_details.rb will pick up where it left off and process the remaining parcels.

This steps takes about two - three days to complete.

## Results
Upon completion, the MySQL database will be filled with the most recent set of property records and associated
histories.

## Maintenance
The information is updated weekly. To ensure the data is kept up-to-date, execute the following command to 
update only the changes in the past seven days. 

TODO: Need to complete

```
$ ruby ...
```

## Fill in missing child records
Each child record has a method to determine the missing records. 

TODO: Implement a method to extract that data from the missing records from the web site.