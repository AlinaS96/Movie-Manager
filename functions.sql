-- DROP FUNCTION "getall_movies"()
-- get all the movies in the table
CREATE OR REPLACE FUNCTION "getall_movies"(_userid integer) RETURNS TABLE (
        id integer,
        name varchar,
        releasedate DATE,
        minageaudiance integer,
        productioncountry varchar,
        creationtime timestamp,
        userid integer,
        watched boolean,
        rating decimal
    ) as $$ begin RETURN QUERY
SELECT m.*,
    wm.userid,
    CASE
        WHEN wm.userid > 0 THEN true
        ELSE false
    END "watched",
    ROUND(AVG(r.rate), 2) as "rating"
FROM "movie" m
    LEFT JOIN "watchedmovie" wm on m.id = wm.movieid
    and wm.userid = _userid
    LEFT JOIN "rating" r on r.movieid = m.id
GROUP BY m.id,
    m.name,
    m.releasedate,
    m.minageaudiance,
    m.productioncountry,
    wm.userid,
    "watched";
end;
$$ language plpgsql;
select *
from "getall_movies"(100);
-- DROP FUNCTION "get_user_movie"(_moieid integer, _userid integer)
-- get single movie details of user.
CREATE OR REPLACE FUNCTION "get_user_movie"(_movieid integer, _userid integer) RETURNS TABLE (
        id integer,
        name varchar,
        releasedate DATE,
        minageaudiance integer,
        productioncountry varchar,
        bookmark timestamp,
        genras varchar [],
        rate integer,
		castname varchar[]
    ) as $$ begin RETURN QUERY
	SELECT t.*, array_agg(c.name) as "castname" FROM 
	(SELECT m.id,
		m.name,
		m.releasedate,
		m.minageaudiance,
		m.productioncountry,
		wm.creationtime as "bookmark",
		array_agg(g.name) as "genras",
		r.rate
	FROM Movie m
		LEFT JOIN "moviegenra" mg ON mg."movieid" = m."id"
		LEFT JOIN "genra" g ON g."id" = mg."genraid"
		LEFT JOIN "rating" r ON m.id = r."movieid"
		and r.userid = _userid
		LEFT JOIN "watchedmovie" wm on wm.movieid = m.id
		and wm.userid = _userid
	WHERE m.id = _movieId
	GROUP BY m.id,
		m.name,
		m.releasedate,
		m.minageaudiance,
		m.productioncountry,
		wm.creationtime,
		r.movieid,
		r.userid,
		r.rate) as t LEFT JOIN "moviecast" mc on mc.movieid = t.id LEFT JOIN "cast" c on c.id = mc.castid
	GROUP BY t.id, t.name, t.releasedate, t.minageaudiance, t.productioncountry, t."bookmark", t."genras", t.rate;
end;
$$ language plpgsql;

SELECT *
FROM "get_user_movie"(3, 1) LIMIT 1;
-- DROP function "get_user"(_username varchar, _passwrod varchar)
-- get current user.
CREATE OR REPLACE FUNCTION "get_user"(_username varchar, _password varchar) RETURNS TABLE (username varchar, password varchar, id integer) as $$ begin RETURN QUERY
SELECT u.username,
    u.password,
    u.id
FROM "user" u
WHERE u.username = _username
    and u.password = _password;
end;
$$ language plpgsql;
-- set rating of the movie by the user.
CREATE OR REPLACE FUNCTION "set_rating"(
        _movieid integer,
        _userid integer,
        _rating integer
    ) RETURNS integer as $$
DECLARE mid integer;
begin -- SELECT u.username, u.password, u.id FROM "User" u WHERE u.username = _username and u.password = _password;
mid := (
    SELECT r.movieid
    FROM "rating" r
    where r.userid = _userid
        and r.movieid = _movieid
    LIMIT 1
);
if mid > 0 then -- DELETE FROM rating r WHERE r.movieid = _movieid and r.userid = _userid;
update "rating" r
set rate = _rating
where r.movieid = _movieid
    and r.userid = _userid;
RETURN 0;
-- the action of updating something.
else -- update rating set rate = 
INSERT INTO "rating"
VALUES (_userid, _movieid, _rating, CURRENT_TIMESTAMP);
RETURN 1;
end if;
end;
$$ language plpgsql;
-- remove rating of user of a movie.
CREATE OR REPLACE FUNCTION "remove_rating"(_movieid integer, _userid integer) RETURNS integer as $$
DECLARE mid integer;
begin -- SELECT u.username, u.password, u.id FROM "User" u WHERE u.username = _username and u.password = _password;
DELETE FROM "rating" r
WHERE r.movieid = _movieid
    and r.userid = _userid;
RETURN 0;
end;
$$ language plpgsql;
-- SELECT "remove_rating"(1, 1);
-- get all the movie ratings.
CREATE OR REPLACE FUNCTION "getall_movie_ratings"(_userid integer) RETURNS TABLE (
        id integer,
        name varchar,
        releasedate DATE,
        minageaudiance integer,
        productioncountry varchar,
        creationtime timestamp
    ) as $$ begin RETURN QUERY
SELECT m.*
FROM "movie" m,
    "rating" r
WHERE m.id = r.movieid
    and r.userid = _userid;
end;
$$ language plpgsql;
SELECT *
FROM "getall_movie_ratings"(2);
-- bookmark and unbookmark movies.
CREATE OR REPLACE FUNCTION "add_or_remove_watchmovie"(_movieid integer, _userid integer) RETURNS integer as $$
DECLARE mid integer;
begin -- SELECT u.username, u.password, u.id FROM "User" u WHERE u.username = _username and u.password = _password;
mid := (
    SELECT w.movieid
    FROM "watchedmovie" w
    where w.userid = _userid
        and w.movieid = _movieid
    LIMIT 1
);
if mid > 0 then
DELETE FROM "watchedmovie" w
WHERE w.movieid = _movieid
    and w.userid = _userid;
RETURN 0;
else
INSERT INTO "watchedmovie"
VALUES (_movieid, _userid, CURRENT_TIMESTAMP);
RETURN 1;
end if;
end;
$$ language plpgsql;
-- select "add_or_remove_watchmovie"(2, 1);
-- getting all the watched movies.
CREATE OR REPLACE FUNCTION "getall_watchedmovies"(_userid integer) RETURNS TABLE (
        id integer,
        name varchar,
        releasedate DATE,
        minageaudiance integer,
        productioncountry varchar,
        creationtime timestamp
    ) as $$ begin RETURN QUERY
SELECT m.*
FROM "movie" m,
    "watchedmovie" w
WHERE m.id = w.movieid
    and w.userid = _userid;
end;
$$ language plpgsql;
SELECT *
FROM "getall_watchedmovies"(1);
-- getting all the suggestions of the user.
CREATE OR REPLACE FUNCTION "getall_watchsuggestions"(_userid integer) RETURNS TABLE (
        id integer,
        name varchar,
        releasedate DATE,
        minageaudiance integer,
        productioncountry varchar,
        creationtime timestamp
    ) as $$ begin RETURN QUERY
SELECT m.*
FROM "movie" m,
    "watchsuggestions" w
WHERE m.id = w.movieid
    and w.userid = _userid;
end;
$$ language plpgsql;
select *
from "getall_watchsuggestions"(2);
-- inserting a cast.
CREATE OR REPLACE FUNCTION "insert_cast"(_name varchar, _dob date, _gender Gender) RETURNS integer as $$
DECLARE tableId integer;
begin
INSERT INTO "cast" (name, DOB, gender)
VALUES (_name, _dob, _gender)
RETURNING id into tableId;
RETURN tableId;
end;
$$ language plpgsql
CREATE OR REPLACE FUNCTION "update_cast"(
        _id integer,
        _name varchar,
        _dob date,
        _gender Gender
    ) RETURNS integer as $$
DECLARE tableId integer;
begin
update "Cast"
set name = _name,
    DOB = _dob,
    gender = _gender
WHERE id = _id
RETURNING id into tableId;
RETURN tableId;
end;
$$ language plpgsql;
-- SELECT "insert_cast"('Hamsworth',  TO_DATE('20170103','YYYYMMDD') , 'Male');
-- SELECT "update_cast"(1, 'Hams-worth', TO_DATE('20170204','YYYYMMDD'), 'Male')
-- SELECT * FROM "Cast";
CREATE OR REPLACE FUNCTION "insert_movie"(
        _name varchar,
        _releaseDate date,
        _minAgeAudiance integer,
        _productionCountry varchar
    ) RETURNS integer as $$
DECLARE tableId integer;
begin
INSERT INTO Movie (
        name,
        releaseDate,
        minAgeAudiance,
        productionCountry,
        creationTime
    )
VALUES (
        _name,
        _releaseDate,
        _minAgeAudiance,
        _productionCountry,
        CURRENT_TIMESTAMP
    )
RETURNING id into tableId;
RETURN tableId;
end;
$$ language plpgsql;
CREATE OR REPLACE FUNCTION "insert_moviecast"(_movieId integer, _castId integer) RETURNS void as $$ begin
INSERT INTO moviecast (castId, movieId)
VALUES (_castId, _movieId);
end;
$$ language plpgsql;
CREATE OR REPLACE FUNCTION "remove_moviecast"(_movieId integer, _castId integer) RETURNS void as $$ begin
DELETE FROM moviecast
WHERE movieId = _movieId
    and castId = _castId;
end;
$$ language plpgsql;
CREATE OR REPLACE FUNCTION "insert_genra"(_name varchar) RETURNS integer as $$
DECLARE tableId integer;
begin
INSERT INTO genra (name, creationTime)
VALUES (_name, CURRENT_TIMESTAMP)
RETURNING id into tableId;
RETURN tableId;
end;
$$ language plpgsql;
CREATE OR REPLACE FUNCTION "insert_moviegenra"(mId integer, gId integer) RETURNS void as $$ begin
INSERT INTO "MovieGenra" (genraid, movieId)
VALUES (gId, mId);
end;
$$ language plpgsql;
CREATE OR REPLACE FUNCTION "get_rating"() RETURNS table (id integer, name varchar, something decimal) language plpgsql as $$ begin RETURN QUERY (
        SELECT m.id,
            m.name,
            ROUND(AVG(rate), 2)
        FROM Rating r,
            Movie m
        where r.movieId = m.id
        GROUP BY m.id,
            m.name
    );
end;
$$ language plpgsql;