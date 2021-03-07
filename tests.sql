-----------------------
-- Delete everything --
-----------------------

-- Use this instead of drop schema if running on the Chalmers Postgres server
-- DROP OWNED BY TDA357_XXX CASCADE;

-- Less talk please.
\set QUIET true
SET client_min_messages TO WARNING;

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;

-----------------------
-- Reload everything --
-----------------------

-- Stop processing files as soon as we find any error.
\set ON_ERROR_STOP on

-- Load your files (they need to be in the same folder as this script!)
\i setup.sql
\i triggers.sql

---------------------------------------------

-- TEST #1: Register for an unlimited course.
-- EXPECTED OUTCOME: Pass
--INSERT INTO Registrations VALUES ('6666666666', 'CCC111'); -- Works!

-- TEST #2: Register an already registered student.
-- EXPECTED OUTCOME: Fail
--INSERT INTO Registrations VALUES ('1111111111', 'CCC111'); -- Works!

-- TEST #3: Unregister from an unlimited course.
-- EXPECTED OUTCOME: Pass
--DELETE FROM Registrations WHERE student = '6666666666' AND course = 'CCC111';

-- TEST #4: Register to a limited course.
-- EXPECTED OUTCOME: Pass
--INSERT INTO Registrations VALUES ('6666666666', 'CCC222'); -- Works!

-- TEST #5: Register to a course without passing the required courses.
-- EXPECTED OUTCOME: Fail
--INSERT INTO Registrations VALUES ('6666666666', 'CCC555'); -- Works!

-- TEST #6: Register to a course which they have already passed.
-- EXPECTED OUTCOME: Fail
--INSERT INTO Registrations VALUES ('4444444444', 'CCC111'); -- Works!

-- TO DO!
-- TEST #7: Unregister from a limited course with a waiting list, when the student is registered.
-- EXPECTED OUTCOME: Pass
--DELETE FROM Registrations WHERE student = '6666666666' AND course = 'CCC111';

-- TEST #8: Unregister from a limited course with a waiting list, when the student is in the middle of the waiting list.
-- EXPECTED OUTCOME: Pass
--DELETE FROM Registrations WHERE student = '6666666666' AND course = 'CCC111';

-- TEST #9: Unregister from an overfull course with a waiting list.
-- EXPECTED OUTCOME: Pass
--DELETE FROM Registrations WHERE student = '6666666666' AND course = 'CCC111';

---------------------------------------------

SELECT student, course, status FROM Registrations;
--SELECT course, student, position FROM WaitingList;
SELECT course, student, place FROM CourseQueuePosition;