-- get result of genra.
SELECT m.name,
	array_agg(g.name) as genras
FROM movie m,
	genra g,
	"moviegenra" mg
WHERE m.id = mg."movieid"
	and g.id = mg."genraid"
group by m.name;

SELECT * FROM "genra";
-- resources for rating.
--DROP TRIGGER validate_rating_trigger on "rating"
-- this trigger has been droped please do not use this trigger
CREATE TRIGGER validate_rating_trigger BEFORE
INSERT
	OR
UPDATE ON "rating" FOR EACH ROW EXECUTE FUNCTION validate_rating();

CREATE OR REPLACE FUNCTION validate_rating() RETURNS trigger AS $BODY$ begin IF NEW.rate >= 1
	and NEW.rate <= 100 THEN RETURN NEW;
END IF;
RAISE EXCEPTION 'rating only between 1-100';
end;
$BODY$ language plpgsql;

-- on rating a moive
SELECT *
from "get_rating"(); -- insert trigger in rating. when rating is added trigger is executed to get watch suggesstions

-- DROP TRIGGER add_suggestions_trigger on Rating;
CREATE TRIGGER add_suggestions_trigger BEFORE
INSERT ON Rating FOR EACH ROW EXECUTE FUNCTION add_suggestion();

DROP function add_suggestion
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
$BODY$ language plpgsql; -- delete ratings from watchsuggestions (trigger creation). when rating is ddeleted watch suggestions is gone. 

CREATE TRIGGER delete_suggestions_trigger
AFTER DELETE ON Rating FOR EACH ROW EXECUTE FUNCTION delete_suggestion();

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
















