------------------------------
-- One Key to Rule Them All --
-- Artificial Key DB Script --
-- Ami Levin 2019 ------------
------------------------------

USE master;
GO

IF EXISTS (SELECT NULL FROM master.sys.databases WHERE name = N'Artificial_Keys')
BEGIN
	ALTER DATABASE Artificial_Keys SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE Artificial_Keys;
END
GO

CREATE DATABASE [Artificial_Keys] ON  PRIMARY 
( NAME = N'Artificial_Keys', FILENAME = N'C:\Temp\Artificial_Keys.mdf' , SIZE = 200MB , FILEGROWTH = 100MB )
 LOG ON 
( NAME = N'Artificial_Keys_log', FILENAME = N'C:\Temp\Artificial_Keys_log.LDF' , SIZE = 100MB , FILEGROWTH = 50MB);
GO

ALTER AUTHORIZATION ON DATABASE::Artificial_keys TO sa;
ALTER DATABASE Artificial_Keys SET RECOVERY SIMPLE;
GO

USE	Artificial_Keys;
GO

CREATE TABLE	Countries
(
	CountryID	INT	IDENTITY(1,1)	PRIMARY KEY,
	ISOCode		CHAR(2)				UNIQUE
									NOT NULL,
	Country		VARCHAR(50)			UNIQUE
									NOT NULL
);
GO

INSERT INTO Countries
(ISOCode, Country)
SELECT	Code, Country
FROM	GeoData.dbo.countrycodes;
GO

CREATE TABLE	Cities
(
	CityID		INT IDENTITY(1,1)	PRIMARY KEY,
	City		VARCHAR(50)			UNIQUE
);


INSERT INTO Cities
(City)
SELECT	DISTINCT City
FROM	GeoData.dbo.worldcitiespop;
GO

CREATE TABLE CountryCities
(
	CountryCityID	INT IDENTITY(1,1)	NOT NULL
										PRIMARY KEY,
	CountryID		INT					NOT NULL,
	CityID			INT					NOT NULL
);
GO

INSERT INTO	CountryCities
(CountryID, CityID)
SELECT	Co.CountryID, 
		C.CityID
FROM	GeoData.dbo.countrycodes AS CC
		INNER JOIN
		GeoData.dbo.worldcitiespop AS WCP
		ON	CC.Code =	WCP.Country
		INNER JOIN
		dbo.Cities AS C
		ON	C.City	=	WCP.City
		INNER JOIN
		dbo.Countries AS Co
		ON	Co.Country = CC.Country;
GO

ALTER TABLE CountryCities
ADD		CONSTRAINT		UQ_CountryID_CityID
			UNIQUE	(CountryID, CityID),
		CONSTRAINT		FK_CountryCities_Countries
			FOREIGN KEY (CountryID)
			REFERENCES	Countries(CountryID),
		CONSTRAINT		FK_CountryCities_Cities
			FOREIGN KEY (CityID)
			REFERENCES	Cities(CityID);
GO

CREATE TABLE	WebSites	
(
	WebSiteID		INT IDENTITY(1,1)	PRIMARY KEY,
	[URL]				VARCHAR(128)	UNIQUE 
										NOT NULL,
	CountryCityID	INT					NOT NULL
										REFERENCES CountryCities(CountryCityID),
	FILLER			CHAR(100)			NOT NULL
										DEFAULT (CAST(NEWID() AS CHAR(100)))
);
GO

-- EOF