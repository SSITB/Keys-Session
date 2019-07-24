------------------------------
-- One Key to Rule Them All --
-- Natrual Key DB Script -----
-- Ami Levin 2019 ------------
------------------------------

USE master;
GO

IF EXISTS (SELECT NULL FROM master.sys.databases WHERE name = N'Natural_Keys')
BEGIN
	ALTER DATABASE Natural_Keys SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE Natural_Keys;
END
GO

USE [master]
GO

CREATE DATABASE [Natural_Keys] ON  PRIMARY 
( NAME = N'Natural_Keys', FILENAME = N'C:\Temp\Natural_Keys.mdf' , SIZE = 200MB , FILEGROWTH = 50MB )
 LOG ON 
( NAME = N'Natural_Keys_log', FILENAME = N'C:\Temp\Natural_Keys_log.LDF' , SIZE = 100MB , FILEGROWTH = 50MB);
GO

ALTER AUTHORIZATION ON DATABASE::Natural_keys TO sa;
ALTER DATABASE Natural_Keys SET RECOVERY SIMPLE;
GO

USE Natural_Keys;
GO

CREATE TABLE	Countries
(
	Country		VARCHAR(50)		PRIMARY KEY,
	ISOCode		CHAR(2)			UNIQUE
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
	City		VARCHAR(50)	PRIMARY KEY
);
GO

INSERT INTO Cities
(City)
SELECT	DISTINCT City
FROM	GeoData.dbo.worldcitiespop;
GO

CREATE TABLE	CountryCities
(
	Country		VARCHAR(50)	NOT NULL,
	City		VARCHAR(50)	NOT NULL,
	CONSTRAINT	PK_CountryCities
				PRIMARY KEY (Country, City)
);
GO

INSERT INTO CountryCities
(Country, City)
SELECT	CC.Country, WCP.City
FROM	GeoData.dbo.worldcitiespop AS WCP
		INNER JOIN
		GeoData.dbo.countrycodes AS CC
		ON CC.Code = WCP.Country;
GO

ALTER TABLE	CountryCities
ADD	CONSTRAINT	FK_CountryCities_Countries
		FOREIGN KEY	(Country)
		REFERENCES	Countries(Country)
		ON UPDATE	CASCADE
		ON DELETE	NO ACTION,
	CONSTRAINT	FK_CountryCities_Cities
		FOREIGN KEY	(City)
		REFERENCES	Cities(City)
		ON UPDATE	CASCADE
		ON DELETE	NO ACTION;
GO

CREATE TABLE	WebSites	
(
	URL			VARCHAR(128)		PRIMARY KEY,
	Country		VARCHAR(50)			NOT NULL,
	City		VARCHAR(50)			NOT NULL,
	FILLER		CHAR(100)			NOT NULL
									DEFAULT (CAST(NEWID() AS CHAR(100))),
	CONSTRAINT	FK_WebSites_CountryCities
				FOREIGN KEY (Country, City)
				REFERENCES	CountryCities(Country, City)
				ON UPDATE CASCADE
				ON DELETE NO ACTION								
);
GO

-- EOF