------------------------------
-- One Key to Rule Them All --
-- Demo Script ---------------
-- Ami Levin 2019 ------------
------------------------------

USE Master;
GO

-- Check Database Sizes Pre-Data Loading
EXEC Artificial_Keys..sp_spaceused @updateusage = 'TRUE', @oneresultset = 1;
EXEC Natural_Keys..sp_spaceused @updateusage = 'TRUE' , @oneresultset = 1;
GO

-- Load ~100K Rows of Data
-- Prepare staging table
DROP TABLE IF EXISTS #WebSites;
CREATE TABLE #WebSites	(
						URL				VARCHAR(128) PRIMARY KEY,
						Country			VARCHAR(50),
						City			VARCHAR(50),
						CountryCityID	INT
						);
GO

-- Load with non-linear proportional number of sites to population
WITH	
TopCountryCities (Country, City, Population)
AS
(	
	SELECT	TOP (50000) CC.Country, WCP.City, WCP.[Population]
	FROM	GeoData.dbo.countrycodes AS CC
			INNER JOIN
			GeoData.dbo.worldcitiespop AS WCP
		ON	CC.Code =	WCP.Country
	ORDER BY [Population] DESC
),
NTILED (Country, City, Tile)
AS
(
	SELECT	Country, City, NTILE(10) OVER(ORDER BY Population)
	FROM	TopCountryCities
)
INSERT INTO #WebSites
SELECT	N'http://' + CAST(NEWID() AS VARCHAR(36)) + '.com' AS URL,
		NTILED.Country,
		NTILED.City,
		CC.CountryCityID
FROM	NTILED
		INNER JOIN
		(
			VALUES (10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),(10),
					(9),(9),(9),(9),(9),(9),(9),(9),(9),(9),(9),(9),(9),(9),
					(8),(8),(8),(8),(8),(8),(8),(8),(8),(8),
					(7),(7),(7),(7),(7),(7),(7),
					(6),(6),(6),(6),(6),(6),
					(5),(5),(5),(5),(5),
					(4),(4),(4),(4),
					(3),(3),(3),
					(2),(2),
					(1)
		) AS TileMultiply (Tile)
		ON NTILED.Tile = TileMultiply.Tile
		INNER JOIN 
		Artificial_Keys.dbo.Countries AS CO
		ON	CO.Country	=	NTILED.Country
		INNER JOIN
		Artificial_Keys.dbo.Cities AS CI
		ON	CI.City		=	NTILED.City
		INNER JOIN
		Artificial_Keys.dbo.CountryCities AS CC
		ON	CC.CountryID	= CO.CountryID
			AND
			CC.CityID		= CI.CityID;
GO

SELECT TOP 100 *
FROM #WebSites
GO

--BENCHMARK INSERT
-- Turn off SSMS execution plan if on...
-- Artificial Keys
DECLARE URL_Cursor CURSOR SCROLL STATIC
FOR
SELECT	URL, Country, City, CountryCityID
FROM	#WebSites
ORDER BY NEWID() -- RANDOM ORDER

SET NOCOUNT ON;

OPEN URL_Cursor;

DECLARE @URL VARCHAR(128), @Country VARCHAR(50), @City VARCHAR(50), @CountryCityID INT;

FETCH NEXT FROM URL_Cursor INTO @URL, @Country, @City, @CountryCityID;

WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO Artificial_Keys.dbo.WebSites	(
												URL,
												CountryCityID
												)
	VALUES	(@URL, @CountryCityID);

	FETCH NEXT FROM URL_Cursor INTO @URL, @Country, @City, @CountryCityID;
END
GO

--------------
DECLARE @URL VARCHAR(128), @Country VARCHAR(50), @City VARCHAR(50), @CountryCityID INT;

FETCH FIRST FROM URL_Cursor INTO @URL, @Country, @City, @CountryCityID;

WHILE @@FETCH_STATUS = 0
BEGIN
-- Natural Keys
	INSERT INTO Natural_Keys.dbo.WebSites	(
											URL,
											Country,
											City
											)
	VALUES	(@URL, @Country, @City);

	FETCH NEXT FROM URL_Cursor INTO @URL, @Country, @City, @CountryCityID;
END
GO

CLOSE URL_Cursor;
DEALLOCATE URL_Cursor;
GO

-- Check Database Sizes Post-Data Loading
EXEC Artificial_Keys..sp_spaceused @updateusage = 'TRUE', @oneresultset = 1;
EXEC Natural_Keys..sp_spaceused @updateusage = 'TRUE' , @oneresultset = 1;
GO

-- Check Fragmanatation levels on clustered index
USE Artificial_Keys;
SELECT * FROM sys.dm_db_index_physical_stats
    (DB_ID(N'Artificial_Keys'), OBJECT_ID(N'dbo.WebSites'), 1, NULL , NULL);
GO

USE Natural_Keys;
SELECT * FROM sys.dm_db_index_physical_stats
    (DB_ID(N'Natural_Keys'), OBJECT_ID(N'dbo.WebSites'), 1, NULL , NULL);
GO

-- Check Fragmanatation levels on clustered index
USE Artificial_Keys;
SELECT * FROM sys.dm_db_index_physical_stats
    (DB_ID(N'Artificial_Keys'), OBJECT_ID(N'dbo.WebSites'), NULL, NULL , NULL);
GO

-- Rebuild all large tables and shrink (don't do this at home...)
ALTER INDEX ALL ON Artificial_Keys..WebSites REBUILD;
ALTER INDEX ALL ON Natural_Keys..WebSites REBUILD;
ALTER INDEX ALL ON Artificial_Keys..CountryCities REBUILD;
ALTER INDEX ALL ON Natural_Keys..CountryCities REBUILD;
ALTER INDEX ALL ON Artificial_Keys..Cities REBUILD;
ALTER INDEX ALL ON Natural_Keys..Cities REBUILD;

DBCC SHRINKDATABASE (Artificial_Keys, 10);
DBCC SHRINKDATABASE (Natural_Keys, 10);

-- Check Database Sizes Post REBUILD and SHRINK
EXEC Artificial_Keys..sp_spaceused @updateusage = 'TRUE', @oneresultset = 1;
EXEC Natural_Keys..sp_spaceused @updateusage = 'TRUE' , @oneresultset = 1;
GO

------------
--QUERIES --
------------

USE master;
GO

--SET STATISTICS IO ON
--GO

-- Look for a particular URL (singleton lookup)
SELECT	*
FROM	Artificial_Keys.dbo.WebSites
WHERE	URL = 'http://DoesntExist';

SELECT	*
FROM	Natural_Keys.dbo.WebSites
WHERE	URL = 'http://DoesntExist';
GO

-- Look for particular Prefix (Range Lookup)
-- Narrow range
SELECT	*
FROM	Artificial_Keys.dbo.WebSites
WHERE	URL LIKE 'http://AA%';

SELECT	*
FROM	Natural_Keys.dbo.WebSites
WHERE	URL LIKE 'http://AA%';
GO

-- Wider range
SELECT	*
FROM	Artificial_Keys.dbo.WebSites
WHERE	URL LIKE 'http://A%';

SELECT	*
FROM	Natural_Keys.dbo.WebSites
WHERE	URL LIKE 'http://A%';
GO

-- Look for top 10 countries with largest number of web sites
SELECT	C.Country, COUNT(*) AS NumberOfWebSites
FROM	Artificial_Keys.dbo.WebSites AS WS
		INNER JOIN
		Artificial_Keys.dbo.CountryCities AS CC
		ON WS.CountryCityID = CC.CountryCityID
		INNER JOIN
		Artificial_Keys.dbo.Countries AS C
		ON C.CountryID = CC.CountryID
GROUP BY C.Country
ORDER BY COUNT(*) DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

SELECT	Country, COUNT(*) AS NumberOfWebSites
FROM	Natural_Keys.dbo.WebSites
GROUP BY Country
ORDER BY COUNT(*) DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

-- Bypass joins even when the key does not cover the query
-- Show Country ISO Codes for all countries that have websites
SELECT	DISTINCT C.ISOCode
FROM	Artificial_Keys.dbo.WebSites AS WS
		INNER JOIN
		Artificial_Keys.dbo.CountryCities AS CC
		ON WS.CountryCityID = CC.CountryCityID
		INNER JOIN
		Artificial_Keys.dbo.Countries AS C
		ON C.CountryID = CC.CountryID
ORDER BY C.ISOCode;
GO

SELECT	DISTINCT C.ISOCode
FROM	Natural_Keys.dbo.WebSites AS WS
		INNER JOIN
		Natural_Keys.dbo.Countries AS C
		ON WS.Country = C.Country
ORDER BY C.ISOCode;
GO

-- Optimization attempt
CREATE NONCLUSTERED INDEX IDX1 ON Artificial_Keys..WebSites(CountryCityID);
CREATE NONCLUSTERED INDEX IDX1 ON Artificial_Keys..CountryCities(CountryID);

CREATE NONCLUSTERED INDEX IDX1 ON Natural_Keys..websites(Country);

--DROP INDEX IDX1 ON Artificial_Keys..WebSites;
--DROP INDEX IDX1 ON Artificial_Keys..CountryCities;
--DROP INDEX IDX1 ON Natural_Keys..websites;

-- Show all Tonga URLS
SELECT	WS.URL
FROM	Artificial_Keys..WebSites AS WS
		INNER JOIN
		Artificial_Keys..CountryCities AS CC
		ON WS.CountryCityID = CC.CountryCityID
		INNER JOIN
		Artificial_Keys.dbo.Countries AS C
		ON C.CountryID = CC.CountryID
WHERE	C.Country = 'Tonga';
GO

SELECT	URL
FROM	Natural_Keys.dbo.WebSites
WHERE	Country = 'Tonga';

-- Show all India URLs
SELECT	WS.URL
FROM	Artificial_Keys.dbo.WebSites AS WS
		INNER JOIN
		Artificial_Keys.dbo.CountryCities AS CC
		ON WS.CountryCityID = CC.CountryCityID
		INNER JOIN
		Artificial_Keys.dbo.Countries AS C
		ON C.CountryID = CC.CountryID
WHERE	C.Country = 'India';
GO

SELECT	URL
FROM	Natural_Keys.dbo.WebSites
WHERE	Country = 'India';

-- What cities are registered in the US?
SELECT	DISTINCT CI.City
FROM	Artificial_Keys.dbo.CountryCities AS CC
		INNER JOIN
		Artificial_Keys.dbo.Countries AS C
		ON C.CountryID = CC.CountryID
		INNER JOIN
		Artificial_Keys.dbo.cities AS CI 
		ON CI.cityID = CC.CityID                       
WHERE	C.Country = 'United States';
GO

SELECT	DISTINCT city
FROM	Natural_Keys.dbo.CountryCities
WHERE	Country = 'United States';
GO

-- What web sites are in jerusalem, israel?
SELECT	WS.[URL]
FROM	Artificial_Keys.dbo.WebSites AS WS
		INNER JOIN
		Artificial_Keys.dbo.CountryCities AS CC
		ON WS.CountryCityID = CC.CountryCityID
		INNER JOIN
		Artificial_Keys.dbo.Countries AS CO
		ON CO.CountryID = CC.CountryID
		INNER JOIN
		Artificial_Keys.dbo.Cities AS CI
		ON CI.CityID = CC.CityID
WHERE	CO.Country = 'Israel'
		AND
		CI.City = 'Jerusalem';

SELECT	[URL]
FROM	Natural_Keys.dbo.WebSites
WHERE	Country = 'Israel'
		AND
		City = 'Jerusalem';
GO

-- Optimization Attempt
CREATE NONCLUSTERED INDEX IDX2 ON Natural_Keys..WebSites(Country, City)

-- DROP INDEX IDX2 ON Natural_Keys..WebSites

-- And the down side?
-- Cote d'Ivoire has decided to change its name to english = Ivory Coast.

SET STATISTICS IO ON;
GO

UPDATE	Artificial_Keys.dbo.Countries
SET		Country = 'Ivory Coast'
WHERE	Country = 'Cote d''Ivoire';
GO

UPDATE	Natural_Keys.dbo.Countries
SET		Country = 'Ivory coast'
WHERE	Country = 'Cote d''Ivoire';
GO

SET STATISTICS IO OFF;
GO

-- Any ideas for additional queries?

-- EOF