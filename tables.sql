-- enumerations.
CREATE TYPE CastType AS ENUM ('Actor', 'Writter', 'Director');
CREATE TYPE Gender AS ENUM ('Male', 'Female');
-- directors, actors, writers who have contributions in movies.
-- DROP TABLE "Cast"
CREATE TABLE IF NOT EXISTS "cast" (
    id SERIAL PRIMARY KEY,
    name varchar(256),
    DOB date,
    gender Gender
);
--DROP PROCEDURE "insert_cast"(_name varchar, _dob date, _gender Gender)
-- differnet types of movie 
CREATE TABLE IF NOT EXISTS "genra" (
    id SERIAL PRIMARY KEY,
    name varchar(256),
    creationTime timestamp
);
CREATE TABLE IF NOT EXISTS "movie" (
    id SERIAL PRIMARY KEY,
    name varchar(256),
    releaseDate date,
    minAgeAudiance integer,
    productionCountry varchar(256),
    creationTime timestamp
);
-- weak entity between movie and genra.
CREATE TABLE IF NOT EXISTS "moviegenra" (
    movieId INT NOT NULL REFERENCES Movie (id) ON DELETE CASCADE ON UPDATE CASCADE,
    genraId INT NOT NULL REFERENCES Genra (id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY(genraId, movieId)
);
-- weak entity between cast (actors) and moviecast
CREATE TABLE IF NOT EXISTS "moviecast" (
    castId integer REFERENCES "cast" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    movieId integer REFERENCES "movie" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY(castId, movieId)
);
-- user to login into the app. and create intereact with app (perhaps)
CREATE TABLE IF NOT EXISTS "user" (
    id SERIAL PRIMARY KEY,
    username varchar(256),
    password varchar(256),
    name varchar(256)
);
-- rating of the movie
CREATE TABLE IF NOT EXISTS "rating" (
    userId integer REFERENCES "user" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    movieId integer REFERENCES "movie" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    rate integer,
    creationTime timestamp,
    PRIMARY KEY(userId, movieId)
);
-- watched movie
CREATE TABLE IF NOT EXISTS "watchedmovie" (
    movieId integer REFERENCES "movie" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    userId integer REFERENCES "user" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    creationTime timestamp,
    PRIMARY KEY (userId, movieId)
);
CREATE TABLE IF NOT EXISTS "watchsuggestions" (
    userId integer REFERENCES "user" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    movieId integer REFERENCES "movie" (id) ON DELETE CASCADE ON UPDATE CASCADE,
    creationTime timestamp
);