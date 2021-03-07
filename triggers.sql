CREATE OR REPLACE VIEW CourseQueuePositions AS
 SELECT wl.course, wl.student, ROW_NUMBER() OVER(PARTITION BY course ORDER BY position) AS place
 FROM WaitingList wl
 LEFT JOIN Students s ON s.idnr = wl.student
 GROUP BY wl.course, wl.student;

CREATE OR REPLACE FUNCTION register() RETURNS trigger AS $register$
    DECLARE
    position TIMESTAMP;
    courseCapacity INTEGER;
    currentStudents INTEGER;
    BEGIN
        -- The student must first fulfill all prerequisites for the course.
        -- First check prerequisite courses then remove all passedCourses.
        IF EXISTS (
            -- Add the prerequisite courses.
            SELECT prereq
            FROM Prerequisites
            WHERE course = NEW.course
            -- Remove all passedCourses.
            EXCEPT
            SELECT course
            FROM PassedCourses
            WHERE student = NEW.student)
        THEN
        RAISE EXCEPTION 'Student does not fulfill all prerequisites for the course!';
        END IF;

        -- It should not be possible for students to register for a course which they have already passed.
        IF EXISTS (
            SELECT course
            FROM PassedCourses
            WHERE student = NEW.student AND course = NEW.course)
        THEN
        RAISE EXCEPTION 'Student has already passed the course!';
        END IF;

        -- It should not be possible to register an already registered student.
        IF (NEW.student, NEW.course)
            IN (
            -- Add the registered table.
            SELECT student, course
            FROM Registered
            -- Add the waiting list.
            UNION
            SELECT student, course
            FROM WaitingList)
        THEN
        RAISE EXCEPTION 'Student already registered for the course!';
        END IF;

        -- If the course is full then the student should be added to the WaitingList.
        IF EXISTS (
            SELECT code FROM LimitedCourses WHERE code = NEW.course) -- Check if the course is a limited course.
            THEN
            currentStudents := (SELECT COUNT(student) FROM Registered WHERE course = NEW.course); -- Get students.
            courseCapacity := (SELECT capacity FROM LimitedCourses WHERE code = NEW.course); -- Get capacity.
            IF (currentStudents >= courseCapacity) -- Check if capacity is exceeded.
            THEN
            position = now();
            INSERT INTO WaitingList VALUES (NEW.student, NEW.course, position);
            END IF;
        RETURN NEW; -- Ends the trigger.
        END IF;

        -- After passing all conditions, add the student to the course.
        INSERT INTO Registered VALUES (NEW.student, NEW.course);

        RETURN NEW;
    END;
$register$ LANGUAGE plpgsql;

CREATE TRIGGER register INSTEAD OF INSERT ON Registrations
    FOR EACH ROW EXECUTE FUNCTION register();

CREATE OR REPLACE FUNCTION deregister() RETURNS trigger AS $deregister$
    DECLARE
    insertStudent CHAR(10);
    courseCapacity INTEGER;
    BEGIN
        -- Check if the student is registered on the waiting list.
        -- If so remove the student and update the waiting list.
        IF EXISTS (
        SELECT course FROM WaitingList WHERE student = OLD.student AND course = OLD.course)
        THEN
        DELETE FROM WaitingList WHERE student = OLD.student AND course = OLD.course;
        RETURN NEW; -- Ends the trigger.
        END IF;

        -- Unregister from a limited course with a waiting list, when the student is registered.
        -- Check if the student is registered on a limited course. If so update the waiting list.
        IF EXISTS (
        SELECT code FROM LimitedCourses WHERE code = OLD.course)
        THEN
        insertStudent := (SELECT student FROM CourseQueuePositions WHERE place = 1 AND course = OLD.course);
        DELETE FROM WaitingList WHERE student = insertStudent AND course = OLD.course;
        INSERT INTO Registered VALUES (insertStudent, OLD.course);
        END IF;

        -- If in Registered, remove the student.
        DELETE FROM Registered WHERE student = OLD.student AND course = OLD.course;

        RETURN OLD;
    END;
$deregister$ LANGUAGE plpgsql;

CREATE TRIGGER deregister INSTEAD OF DELETE ON Registrations
    FOR EACH ROW EXECUTE FUNCTION deregister();