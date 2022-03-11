---------------------------------------------CREATION OF TABLES----------------------------------------------
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
---------------------------------------------CREATION OF FUNCTIONS----------------------------------------------------------
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
        castname varchar []
    ) as $$ begin RETURN QUERY
SELECT t.*,
    array_agg(c.name) as "castname"
FROM (
        SELECT m.id,
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
            r.rate
    ) as t
    LEFT JOIN "moviecast" mc on mc.movieid = t.id
    LEFT JOIN "cast" c on c.id = mc.castid
GROUP BY t.id,
    t.name,
    t.releasedate,
    t.minageaudiance,
    t.productioncountry,
    t."bookmark",
    t."genras",
    t.rate;
end;
$$ language plpgsql;
SELECT *
FROM "get_user_movie"(3, 1)
LIMIT 1;
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
$$ language plpgsql;
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
            movie m
        where r.movieId = m.id
        GROUP BY m.id,
            m.name
    );
end;
$$;
---------------------------------CREATION OF TRIGGERS-------------------------------------------------------
-- get result of genra.
SELECT m.name,
    array_agg(g.name) as genras
FROM movie m,
    genra g,
    "moviegenra" mg
WHERE m.id = mg."movieid"
    and g.id = mg."genraid"
group by m.name;
SELECT *
FROM "genra";
-- resources for rating.
--DROP TRIGGER validate_rating_trigger on "rating"
-- this trigger has been droped please do not use this trigger
CREATE OR REPLACE FUNCTION validate_rating() RETURNS trigger AS $BODY$ begin IF NEW.rate >= 1
    and NEW.rate <= 100 THEN RETURN NEW;
END IF;
RAISE EXCEPTION 'rating only between 1-100';
end;
$BODY$ language plpgsql;
CREATE TRIGGER validate_rating_trigger BEFORE
INSERT
    OR
UPDATE ON "rating" FOR EACH ROW EXECUTE FUNCTION validate_rating();
-- on rating a moive
SELECT *
from "get_rating"();
-- insert trigger in rating. when rating is added trigger is executed to get watch suggesstions
-- DROP TRIGGER add_suggestions_trigger on Rating;
CREATE OR REPLACE FUNCTION add_suggestion() RETURNS trigger AS $BODY$ begin -- SELECT genraid FROM "MovieGenra" WHERE movieid = NEW.movieId
    raise notice 'Value: %',
    NEW.movieId;
INSERT INTO "watchsuggestions" (userid, movieid, creationtime)
SELECT DISTINCT NEW.userId as userid,
    movieid,
    CURRENT_TIMESTAMP
FROM "moviegenra" m
WHERE m.genraid IN (
        SELECT genraid
        FROM "moviegenra"
        WHERE movieid = NEW.movieid
    )
    and - - movieid <> NEW.movieId
    and movieid NOT IN (
        SELECT ws.movieid
        FROM watchsuggestions ws
        where genraid IN (
                SELECT genraid
                FROM "moviegenra"
                WHERE movieid = NEW.movieId
            )
            and NEW.userid = ws.userid
    );
RETURN NEW;
end;
$BODY$ language plpgsql;
CREATE TRIGGER add_suggestions_trigger BEFORE
INSERT ON Rating FOR EACH ROW EXECUTE FUNCTION add_suggestion();
-- DROP function add_suggestion;
-- delete ratings from watchsuggestions (trigger creation). when rating is ddeleted watch suggestions is gone. 
CREATE OR REPLACE FUNCTION delete_suggestion() RETURNS trigger AS $BODY$ begin raise notice 'Value: %',
    OLD.movieid;
DELETE FROM watchsuggestions w
WHERE w.movieid in (
        SELECT nm.id
        FROM movie nm,
            "moviegenra" nmg
        WHERE nm.id = nmg.movieId
            and nmg.genraid in (
                SELECT mg.genraid
                from movie m,
                    "moviegenra" mg
                where m.id = mg.movieid
                    and m.id = OLD.movieid
            )
            and w.userid = OLD.userid
    );
RETURN NEW;
end;
$BODY$ language plpgsql;
CREATE TRIGGER delete_suggestions_trigger
AFTER DELETE ON Rating FOR EACH ROW EXECUTE FUNCTION delete_suggestion();
---------------------------------------INSERT QUERIES---------------------------------------------------------------------------------
INSERT INTO public."cast"
VALUES (2, 'tobey maguire ', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (3, 'kristen dunst', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (4, 'andre garfeild', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (5, 'tom holand', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (6, 'stephanie beatriz', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (7, 'giacomo', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (8, 'emma stone', '1990-01-01', 'Male');
INSERT INTO public."cast"
VALUES (9, 'benedict cumburbach', '1990-01-01', 'Male');
INSERT INTO public.genra
VALUES (1, 'Fiction', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (2, 'Narrative', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (3, 'Thriller', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (
        4,
        'Science Fiction',
        '2022-01-24 05:42:10.656793'
    );
INSERT INTO public.genra
VALUES (5, 'Horror', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (6, 'Novel', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (7, 'Action', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (8, 'Comedy', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (9, 'Humor', '2022-01-24 05:42:10.656793');
INSERT INTO public.genra
VALUES (10, 'Action', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (11, 'sci-fi', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (12, 'Drama', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (13, 'Animated', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (14, 'Fantasy', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (15, 'Comedy', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (16, 'Musical', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (17, 'Crime', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (18, 'Adventure', '2022-02-08 13:42:30.803635');
INSERT INTO public.genra
VALUES (19, 'History', '2022-02-08 13:59:05.821108');
INSERT INTO public.genra
VALUES (20, 'Family', '2022-02-08 13:59:05.821108');
INSERT INTO public.genra
VALUES (21, 'Teen', '2022-02-08 13:59:05.821108');
INSERT INTO public.movie
VALUES (
        1,
        'wonderland',
        '2022-01-20',
        13,
        'USA',
        '2022-01-20 09:07:34.173806'
    );
INSERT INTO public.movie
VALUES (
        2,
        'Avengers Endgame',
        '2022-01-20',
        13,
        'USA',
        '2022-01-20 09:39:11.580617'
    );
INSERT INTO public.movie
VALUES (
        3,
        'Captin America And The Winter Solider',
        '2022-01-20',
        13,
        'USA',
        '2022-01-20 09:39:11.580617'
    );
INSERT INTO public.movie
VALUES (
        4,
        'Free Guy',
        '2020-01-01',
        13,
        'USA',
        '2022-01-24 04:59:34.104217'
    );
INSERT INTO public.movie
VALUES (
        5,
        'Spider-Man 1',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:36:58.265898'
    );
INSERT INTO public.movie
VALUES (
        7,
        'The Amazing Spiderman',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        8,
        'Spider-Man:No Way Home',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        9,
        'In the heights',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        10,
        'LegoMovie2',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        11,
        'Luca',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        12,
        'Encanto',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        13,
        'Cruella',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        14,
        'Dr. Strange',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        15,
        'Spider-Man:No Way Home',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        16,
        'The Amazing Spiderman',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        17,
        'Amazing Spiderman',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        18,
        'Spider-Man:No Way Home',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        19,
        'LaLa Land',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        20,
        'The Social Network',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        21,
        'Ice-Age collison',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        22,
        'Uncharted',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        23,
        'Mean girls',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        24,
        'Captain America: Civil War',
        '2017-03-04',
        13,
        'UNITED STATE OF AMERICA',
        '2022-02-08 13:37:42.025984'
    );
INSERT INTO public.movie
VALUES (
        25,
        'Spider-Man 2',
        '2020-04-01',
        13,
        'USA',
        '2022-02-09 15:27:34.732775'
    );
INSERT INTO public.moviecast
VALUES (2, 1);
INSERT INTO public.moviecast
VALUES (3, 1);
INSERT INTO public.moviecast
VALUES (4, 1);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (1, 1);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (2, 1);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (1, 2);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (5, 3);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (3, 3);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (5, 4);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (2, 4);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (5, 7);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (7, 5);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (10, 5);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (7, 6);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (11, 6);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (7, 7);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (7, 8);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (11, 8);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (18, 8);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (12, 9);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (14, 9);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (16, 9);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (13, 10);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (18, 10);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (15, 10);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (13, 11);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (14, 11);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (15, 11);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (8, 12);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (13, 12);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (16, 12);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (17, 13);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (10, 14);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (18, 14);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (7, 15);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (11, 15);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (18, 15);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (7, 16);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (19, 16);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (19, 20);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (18, 21);
INSERT INTO public.moviegenra (movieid, genraid)
VALUES (20, 21);
INSERT INTO public."user"
VALUES (1, 'mansoor123', 'mansoor123', 'mansoor');
INSERT INTO public."user"
VALUES (2, 'jhon123', 'mansoor123', 'Jhon Doe');
INSERT INTO public."user"
VALUES (3, 'william123', 'mansoor123', 'William Doe');
INSERT INTO public."user"
VALUES (4, 'sam123', 'mansoor123', 'Sam Billings');
INSERT INTO public."user"
VALUES (6, 'maria123', 'pass123', 'Maria');
INSERT INTO public."user"
VALUES (5, 'alina123', 'pass123', 'Alina');
INSERT INTO public."user"
VALUES (7, 'asad123', 'pass123', 'Asad');
INSERT INTO public."user"
VALUES (8, 'umar123', 'pass123', 'Umar');
INSERT INTO public."user"
VALUES (9, 'ali123', 'pass123', 'Ali');
INSERT INTO public."user"
VALUES (10, 'khan123', 'pass123', 'Khan');
INSERT INTO public."user"
VALUES (11, 'haris123', 'pass123', 'Haris');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 4, 80, '2022-02-05 13:51:21.594491');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 2, 100, '2022-02-05 13:52:16.098702');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 3, 80, '2022-02-05 14:13:04.025698');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (3, 3, 100, '2022-02-05 14:13:51.249018');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (4, 3, 20, '2022-02-05 14:14:12.529305');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 14, 60, '2022-02-09 09:06:05.421999');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 23, 80, '2022-02-09 10:13:19.061313');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 3, 100, '2022-02-09 09:07:14.430158');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 24, 100, '2022-02-09 10:15:38.34125');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 19, 100, '2022-02-09 10:15:42.684965');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 12, 80, '2022-02-09 10:15:45.933127');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 16, 100, '2022-02-09 10:15:57.052101');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 10, 100, '2022-02-09 10:16:05.316231');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 13, 100, '2022-02-09 10:16:11.252458');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 21, 80, '2022-02-09 10:16:15.004674');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 17, 100, '2022-02-09 10:16:18.588582');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 8, 80, '2022-02-09 10:16:23.300209');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 15, 80, '2022-02-09 10:16:26.365068');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 18, 100, '2022-02-09 10:16:31.188511');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 22, 100, '2022-02-09 10:16:36.3489');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 7, 2, '2022-02-09 16:10:43.979255');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 5, 50, '2022-02-09 16:16:10.415242');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 10, 70, '2022-02-09 16:17:00.945856');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (1, 21, 25, '2022-02-09 16:17:00.945856');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (10, 8, 80, '2022-02-09 16:17:00.945856');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (5, 5, 60, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (5, 19, 65, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (5, 25, 25, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 13, 75, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 24, 90, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 22, 100, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 9, 25, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 10, 60, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 19, 40, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (6, 25, 40, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (7, 20, 90, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (7, 23, 40, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (7, 25, 30, '2022-02-09 16:31:46.678161');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 20, 100, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 21, 80, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 22, 80, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 23, 80, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 24, 80, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 25, 40, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 9, 30, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 10, 25, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (8, 11, 90, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 7, 100, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 11, 60, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 12, 80, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 14, 30, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 19, 90, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 8, 80, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 20, 100, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (9, 24, 60, '2022-02-09 16:32:14.539735');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (11, 22, 50, '2022-02-09 16:32:26.47038');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (11, 13, 50, '2022-02-09 16:32:26.47038');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (11, 14, 40, '2022-02-09 16:32:26.47038');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 11, 80, '2022-02-09 10:15:51.812988');
INSERT INTO public.rating (userid, movieid, rate, creationtime)
VALUES (2, 7, 80, '2022-02-10 01:12:59.7041');
--
-- TOC entry 3110 (class 0 OID 20596)
-- Dependencies: 212
-- Data for Name: watchedmovie; Type: TABLE DATA; Schema: public; Owner: postgres
--
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (1, 1, '2022-02-09 10:08:23.539614');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (20, 2, '2022-02-09 10:10:55.053386');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (9, 2, '2022-02-09 10:10:55.957699');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (3, 2, '2022-02-09 10:10:56.56579');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (10, 2, '2022-02-09 10:10:57.140548');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (5, 2, '2022-02-09 10:10:59.452905');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (14, 2, '2022-02-09 10:11:00.213531');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (13, 2, '2022-02-09 10:11:00.948918');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (21, 2, '2022-02-09 10:11:01.684913');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (2, 2, '2022-02-09 12:07:09.256809');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (8, 2, '2022-02-09 12:07:10.209844');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (17, 2, '2022-02-09 12:07:10.753545');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (23, 2, '2022-02-09 12:07:11.282335');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (5, 1, '2022-02-09 15:37:16.400013');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (7, 1, '2022-02-09 15:37:16.400013');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (10, 1, '2022-02-09 15:37:16.400013');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (21, 1, '2022-02-09 15:37:16.400013');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (25, 7, '2022-02-09 15:59:53.027574');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (23, 7, '2022-02-09 15:59:53.027574');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (20, 7, '2022-02-09 15:59:53.027574');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (9, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (10, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (12, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (20, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (21, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (22, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (23, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (24, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (25, 8, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (24, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (20, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (8, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (19, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (14, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (12, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (11, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (7, 9, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (8, 10, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (14, 11, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (13, 11, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (22, 11, '2022-02-09 16:03:39.754795');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (5, 5, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (19, 5, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (25, 5, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (13, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (24, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (22, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (9, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (25, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (19, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (10, 6, '2022-02-09 16:08:03.626313');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (11, 2, '2022-02-10 01:05:02.377222');
INSERT INTO public.watchedmovie (movieid, userid, creationtime)
VALUES (7, 2, '2022-02-10 01:12:58.289285');
--