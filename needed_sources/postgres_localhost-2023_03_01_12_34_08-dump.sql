toc.dat                                                                                             0000600 0004000 0002000 00000047171 14377577760 0014500 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        PGDMP           "                {            todoapp     15.2 (Ubuntu 15.2-1.pgdg20.04+1)     15.2 (Ubuntu 15.2-1.pgdg20.04+1) 2    g           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false         h           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false         i           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false         j           1262    59738    todoapp    DATABASE     s   CREATE DATABASE todoapp WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
    DROP DATABASE todoapp;
                postgres    false                     2615    59739    auth    SCHEMA        CREATE SCHEMA auth;
    DROP SCHEMA auth;
                postgres    false         	            2615    59741    category    SCHEMA        CREATE SCHEMA category;
    DROP SCHEMA category;
                postgres    false                     2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                pg_database_owner    false         k           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   pg_database_owner    false    5                     2615    59740    todo    SCHEMA        CREATE SCHEMA todo;
    DROP SCHEMA todo;
                postgres    false         
            2615    59742    utils    SCHEMA        CREATE SCHEMA utils;
    DROP SCHEMA utils;
                postgres    false         �           1247    59744    authrole    TYPE     ?   CREATE TYPE auth.authrole AS ENUM (
    'USER',
    'ADMIN'
);
    DROP TYPE auth.authrole;
       auth          postgres    false    7         �           1247    59804    language    TYPE     D   CREATE TYPE auth.language AS ENUM (
    'UZ',
    'RU',
    'EN'
);
    DROP TYPE auth.language;
       auth          postgres    false    7         �           1247    59836    priority    TYPE     Z   CREATE TYPE todo.priority AS ENUM (
    'LOW',
    'MEDIUM',
    'HIGH',
    'DEFAULT'
);
    DROP TYPE todo.priority;
       todo          postgres    false    8         �           1247    59864    create_todo_dto    TYPE     �   CREATE TYPE todo.create_todo_dto AS (
	title character varying,
	description character varying,
	priority todo.priority,
	category_id integer,
	due_date date
);
     DROP TYPE todo.create_todo_dto;
       todo          postgres    false    8    908         �           1247    59868    update_todo_dto    TYPE     �   CREATE TYPE todo.update_todo_dto AS (
	id integer,
	title character varying,
	description character varying,
	priority todo.priority,
	category_id integer,
	due_date date,
	is_done boolean
);
     DROP TYPE todo.update_todo_dto;
       todo          postgres    false    8    908                    1255    59812 0   auth_login(character varying, character varying)    FUNCTION     �  CREATE FUNCTION auth.auth_login(uname character varying, pswd character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    t_authuser record;
begin
    select * into t_authuser from auth.authuser where username = lower(uname);
    if not FOUND or not utils.match_password(pswd, t_authuser.password) then
        raise exception 'Bad credentials';
    end if;


    -- return row_to_json(t_authuser)::text;
    return json_build_object(
            'id', t_authuser.id,
            'username', t_authuser.username,
            'role', t_authuser.role,
            'language', t_authuser.language,
            'created_date', t_authuser.created_at
        )::text;
end
$$;
 P   DROP FUNCTION auth.auth_login(uname character varying, pswd character varying);
       auth          postgres    false    7         �            1255    59763 3   auth_register(character varying, character varying)    FUNCTION     �  CREATE FUNCTION auth.auth_register(uname character varying, pswd character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newID       int;
begin

    if exists(select * from auth.authuser a where a.username ilike uname) then
        raise exception 'Username "%" already taken', uname;
    end if;

    insert into auth.authuser (username, password)
    values (uname, utils.encode_password(pswd))
    returning id into newID;
    return newID;
end
$$;
 S   DROP FUNCTION auth.auth_register(uname character varying, pswd character varying);
       auth          postgres    false    7                    1255    59834    hasrole(auth.authrole, integer)    FUNCTION     H  CREATE FUNCTION auth.hasrole(role auth.authrole, userid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_authuser record;
begin
    select * into t_authuser from auth.authuser a where a.id = userid;
    if FOUND then
        return t_authuser.role = role;
    else
        return false;
    end if;
end
$$;
 @   DROP FUNCTION auth.hasrole(role auth.authrole, userid integer);
       auth          postgres    false    7    896         
           1255    59830    isactive(integer) 	   PROCEDURE     �   CREATE PROCEDURE auth.isactive(IN userid integer)
    LANGUAGE plpgsql
    AS $$
begin
    if not exists(select *  from auth.authuser a where a.id = userid) then
        raise 'User not found : "%"',userid;
    end if;
end
$$;
 1   DROP PROCEDURE auth.isactive(IN userid integer);
       auth          postgres    false    7                    1255    59831 +   create_category(character varying, integer)    FUNCTION     N  CREATE FUNCTION category.create_category(title character varying, userid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newID      int;
begin
    call auth.isactive(userid);
    
    insert into category.category (title, user_id)
    values (title, userid)
    returning id into newID;

    return newID;
end
$$;
 Q   DROP FUNCTION category.create_category(title character varying, userid integer);
       category          postgres    false    9                    1255    59832 !   delete_category(integer, integer)    FUNCTION     [  CREATE FUNCTION category.delete_category(categoryid integer, userid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_category record;
begin

    call auth.isactive(userid);

    select * into t_category from category.category c where c.id = categoryid;

    if not FOUND then
        raise exception 'Category not found : "%"',categoryid;
    end if;

    if auth.hasrole('ADMIN', userid) or userid = t_category.user_id then
        delete from category.category c where c.id = categoryid;
    else
        raise exception 'Permission denied';
    end if;

    return true;
end
$$;
 L   DROP FUNCTION category.delete_category(categoryid integer, userid integer);
       category          postgres    false    9                    1255    59861    create_todo(text, integer)    FUNCTION     x  CREATE FUNCTION todo.create_todo(dataparam text, userid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newID      int;
    dataJson   json;
    t_category record;
    dto        todo.create_todo_dto;
begin
    call auth.isactive(userid);
    
    if dataparam is null then
        raise exception 'Dataparam invalid';
    end if;

    dataJson := dataparam::json;

    dto.title := dataJson ->> 'title';
    dto.description := dataJson ->> 'description';
    dto.category_id := dataJson ->> 'category_id';
    dto.priority := coalesce(dataJson ->> 'priority', 'DEFAULT');
    dto.due_date := dataJson ->> 'due_date';

    select * into t_category from category.category c where c.id = dto.category_id;

    if not FOUND then
        raise exception 'Category not Found "%"',dto.category_id;
    end if;

    if t_category.user_id <> userid then
        raise exception 'Permission denied';
    end if;

    insert into todo.todo (title, description, priority, category_id, due_date)
    values (dto.title, dto.description, dto.priority, dto.category_id, dto.due_date)
    returning id into newID;
    return newID;
end
$$;
 @   DROP FUNCTION todo.create_todo(dataparam text, userid integer);
       todo          postgres    false    8                    1255    59869 '   update_todo(character varying, integer)    FUNCTION     �  CREATE FUNCTION todo.update_todo(dataparam character varying, userid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_todo     record;
    t_category record;
    dataJson   json;
    dto        todo.update_todo_dto;
begin
    call auth.isactive(userid);

    if dataparam is null then
        raise exception 'Dataparam invalid';
    end if;

    dataJson := dataparam::json;
    dto.id := dataJson ->> 'id';

    select * into t_todo from todo.todo t where t.id = dto.id;

    if not FOUND then
        raise exception 'Todo not found "%"',dto.id;
    end if;

    select * into t_category from category.category c where c.id = t_todo.category_id;
    
    if not FOUND or t_category.user_id <> userid then
        raise exception 'Permission denied';
    end if;


    dto.title := coalesce(dataJson ->> 'title', t_todo.title);
    dto.description := coalesce(dataJson ->> 'description', t_todo.description);
    dto.priority := coalesce(dataJson ->> 'priority', t_todo.priority::text);
    dto.due_date := coalesce(dataJson ->> 'due_date', t_todo.due_date::text);
    dto.is_done := coalesce(dataJson ->> 'is_done', t_todo.is_done::text);


    update todo.todo
    set title       = dto.title,
        description = dto.description,
        priority    = dto.priority,
        due_date    = dto.due_date,
        is_done     = dto.is_done
    where id = dto.id;

    return true;

end
$$;
 M   DROP FUNCTION todo.update_todo(dataparam character varying, userid integer);
       todo          postgres    false    8                    1255    59870    user_todos_by_category(integer)    FUNCTION     +  CREATE FUNCTION todo.user_todos_by_category(userid integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
begin
    call auth.isactive(userid);

    return (select json_agg(json_build_object(
            'category_id', category_id,
            'category_name', category_name,
            'user_id', user_id,
            'todos', todos))
            from (select t.category_id,
                         c.title  category_name,
                         c.user_id,
                         json_agg(
                                 json_build_object(
                                         'id', t.id,
                                         'title', t.title,
                                         'description', t.description,
                                         'due_date', t.due_date,
                                         'priority', t.priority,
                                         'is_done', t.is_done,
                                         'created_at', t.created_at
                                     )
                             ) as todos
                  from todo t
                           inner join category.category c on c.id = t.category_id
                  where c.user_id = userid
                  group by t.category_id, c.title, c.user_id) as category_details)::text;
end
$$;
 ;   DROP FUNCTION todo.user_todos_by_category(userid integer);
       todo          postgres    false    8                    1255    59801 "   encode_password(character varying)    FUNCTION     �   CREATE FUNCTION utils.encode_password(raw_password character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
begin
    return utils.crypt(raw_password, utils.gen_salt('bf', 4));
end
$$;
 E   DROP FUNCTION utils.encode_password(raw_password character varying);
       utils          postgres    false    10         	           1255    59802 4   match_password(character varying, character varying)    FUNCTION     �   CREATE FUNCTION utils.match_password(raw_password character varying, encoded_password character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    return encoded_password = utils.crypt(raw_password, encoded_password);
end
$$;
 h   DROP FUNCTION utils.match_password(raw_password character varying, encoded_password character varying);
       utils          postgres    false    10         �            1259    59750    authuser    TABLE     �  CREATE TABLE auth.authuser (
    id integer NOT NULL,
    username character varying NOT NULL,
    password character varying NOT NULL,
    role auth.authrole DEFAULT 'USER'::auth.authrole NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    language auth.language DEFAULT 'UZ'::auth.language NOT NULL,
    CONSTRAINT username_length_valid_check CHECK ((length((username)::text) > 4))
);
    DROP TABLE auth.authuser;
       auth         heap    postgres    false    896    902    896    7    902         �            1259    59749    authuser_id_seq    SEQUENCE     �   CREATE SEQUENCE auth.authuser_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE auth.authuser_id_seq;
       auth          postgres    false    220    7         l           0    0    authuser_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE auth.authuser_id_seq OWNED BY auth.authuser.id;
          auth          postgres    false    219         �            1259    59814    category    TABLE     �   CREATE TABLE category.category (
    id integer NOT NULL,
    title character varying NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
    DROP TABLE category.category;
       category         heap    postgres    false    9         �            1259    59813    category_id_seq    SEQUENCE     �   CREATE SEQUENCE category.category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE category.category_id_seq;
       category          postgres    false    222    9         m           0    0    category_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE category.category_id_seq OWNED BY category.category.id;
          category          postgres    false    221         �            1259    59846    todo    TABLE     X  CREATE TABLE todo.todo (
    id integer NOT NULL,
    title character varying,
    description character varying,
    priority todo.priority DEFAULT 'DEFAULT'::todo.priority NOT NULL,
    category_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    due_date date,
    is_done boolean DEFAULT false
);
    DROP TABLE todo.todo;
       todo         heap    postgres    false    908    8    908         �            1259    59845    todo_id_seq    SEQUENCE     �   CREATE SEQUENCE todo.todo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
     DROP SEQUENCE todo.todo_id_seq;
       todo          postgres    false    8    224         n           0    0    todo_id_seq    SEQUENCE OWNED BY     7   ALTER SEQUENCE todo.todo_id_seq OWNED BY todo.todo.id;
          todo          postgres    false    223         �           2604    59753    authuser id    DEFAULT     f   ALTER TABLE ONLY auth.authuser ALTER COLUMN id SET DEFAULT nextval('auth.authuser_id_seq'::regclass);
 8   ALTER TABLE auth.authuser ALTER COLUMN id DROP DEFAULT;
       auth          postgres    false    219    220    220         �           2604    59817    category id    DEFAULT     n   ALTER TABLE ONLY category.category ALTER COLUMN id SET DEFAULT nextval('category.category_id_seq'::regclass);
 <   ALTER TABLE category.category ALTER COLUMN id DROP DEFAULT;
       category          postgres    false    221    222    222         �           2604    59849    todo id    DEFAULT     ^   ALTER TABLE ONLY todo.todo ALTER COLUMN id SET DEFAULT nextval('todo.todo_id_seq'::regclass);
 4   ALTER TABLE todo.todo ALTER COLUMN id DROP DEFAULT;
       todo          postgres    false    223    224    224         `          0    59750    authuser 
   TABLE DATA           T   COPY auth.authuser (id, username, password, role, created_at, language) FROM stdin;
    auth          postgres    false    220       3424.dat b          0    59814    category 
   TABLE DATA           D   COPY category.category (id, title, user_id, created_at) FROM stdin;
    category          postgres    false    222       3426.dat d          0    59846    todo 
   TABLE DATA           j   COPY todo.todo (id, title, description, priority, category_id, created_at, due_date, is_done) FROM stdin;
    todo          postgres    false    224       3428.dat o           0    0    authuser_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('auth.authuser_id_seq', 6, true);
          auth          postgres    false    219         p           0    0    category_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('category.category_id_seq', 8, true);
          category          postgres    false    221         q           0    0    todo_id_seq    SEQUENCE SET     8   SELECT pg_catalog.setval('todo.todo_id_seq', 12, true);
          todo          postgres    false    223         �           2606    59760    authuser authuser_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY auth.authuser
    ADD CONSTRAINT authuser_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY auth.authuser DROP CONSTRAINT authuser_pkey;
       auth            postgres    false    220         �           2606    59762    authuser authuser_username_key 
   CONSTRAINT     [   ALTER TABLE ONLY auth.authuser
    ADD CONSTRAINT authuser_username_key UNIQUE (username);
 F   ALTER TABLE ONLY auth.authuser DROP CONSTRAINT authuser_username_key;
       auth            postgres    false    220         �           2606    59822    category category_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY category.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY category.category DROP CONSTRAINT category_pkey;
       category            postgres    false    222         �           2606    59855    todo todo_pkey 
   CONSTRAINT     J   ALTER TABLE ONLY todo.todo
    ADD CONSTRAINT todo_pkey PRIMARY KEY (id);
 6   ALTER TABLE ONLY todo.todo DROP CONSTRAINT todo_pkey;
       todo            postgres    false    224         �           2606    59823    category category_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY category.category
    ADD CONSTRAINT category_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.authuser(id) ON DELETE CASCADE;
 J   ALTER TABLE ONLY category.category DROP CONSTRAINT category_user_id_fkey;
       category          postgres    false    222    220    3272         �           2606    59856    todo todo_category_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY todo.todo
    ADD CONSTRAINT todo_category_id_fkey FOREIGN KEY (category_id) REFERENCES category.category(id);
 B   ALTER TABLE ONLY todo.todo DROP CONSTRAINT todo_category_id_fkey;
       todo          postgres    false    3276    224    222                                                                                                                                                                                                                                                                                                                                                                                                               3424.dat                                                                                            0000600 0004000 0002000 00000000332 14377577760 0014273 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        6	javohir	$2a$04$VYjoGWT.8G1NRNRlvhRAt.1SYLpTJFTHN8kjJLi7r3HOtUJ.TQf5C	USER	2023-03-01 03:25:26.885467	UZ
5	jlkeesh	$2a$04$BBfp4wlR2ro73Znx5lm7f.pt742lOnzBBYGXrdWa9Tg9VgAV57fPe	ADMIN	2023-03-01 03:01:00.701865	UZ
\.


                                                                                                                                                                                                                                                                                                      3426.dat                                                                                            0000600 0004000 0002000 00000000215 14377577760 0014275 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        4	Learn IT	5	2023-03-01 03:32:32.507113
8	Learn English	5	2023-03-01 04:52:11.630947
5	Learn JAVA With PDP	6	2023-03-01 03:32:57.957778
\.


                                                                                                                                                                                                                                                                                                                                                                                   3428.dat                                                                                            0000600 0004000 0002000 00000001427 14377577760 0014305 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        3	Read About Java	\N	DEFAULT	4	2023-03-01 04:09:28.12648	\N	f
4	Read About Java	\N	DEFAULT	5	2023-03-01 04:09:36.085314	\N	f
5	Learn DSA	Queue,Stack,Dictionary,Tree,Graph	HIGH	4	2023-03-01 04:11:30.578586	2023-03-28	f
6	Learn Micro Services	Read a Book Micro Service in Action, Micro Service Patterns	HIGH	4	2023-03-01 04:18:41.807356	2023-04-10	f
8	Learn AWS	Search From Youtube and Google	HIGH	4	2023-03-01 04:35:14.188938	2023-04-15	t
9	Learn Tenses	google	DEFAULT	8	2023-03-01 04:52:39.838104	\N	f
10	Learn Conditional Clauses	google	DEFAULT	8	2023-03-01 04:52:49.589755	\N	f
11	Read Book about concurreny	Concurrency in Practise pdf	DEFAULT	5	2023-03-01 04:53:34.531674	\N	f
12	Read Book about Java Core	Cay.H Volume I,Cay.H Volume II pdf	DEFAULT	5	2023-03-01 04:54:08.969094	\N	f
\.


                                                                                                                                                                                                                                         restore.sql                                                                                         0000600 0004000 0002000 00000043206 14377577760 0015420 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        --
-- NOTE:
--
-- File paths need to be edited. Search for $$PATH$$ and
-- replace it with the path to the directory containing
-- the extracted data files.
--
--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2 (Ubuntu 15.2-1.pgdg20.04+1)
-- Dumped by pg_dump version 15.2 (Ubuntu 15.2-1.pgdg20.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE todoapp;
--
-- Name: todoapp; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE todoapp WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';


ALTER DATABASE todoapp OWNER TO postgres;

\connect todoapp

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- Name: category; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA category;


ALTER SCHEMA category OWNER TO postgres;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: todo; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA todo;


ALTER SCHEMA todo OWNER TO postgres;

--
-- Name: utils; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA utils;


ALTER SCHEMA utils OWNER TO postgres;

--
-- Name: authrole; Type: TYPE; Schema: auth; Owner: postgres
--

CREATE TYPE auth.authrole AS ENUM (
    'USER',
    'ADMIN'
);


ALTER TYPE auth.authrole OWNER TO postgres;

--
-- Name: language; Type: TYPE; Schema: auth; Owner: postgres
--

CREATE TYPE auth.language AS ENUM (
    'UZ',
    'RU',
    'EN'
);


ALTER TYPE auth.language OWNER TO postgres;

--
-- Name: priority; Type: TYPE; Schema: todo; Owner: postgres
--

CREATE TYPE todo.priority AS ENUM (
    'LOW',
    'MEDIUM',
    'HIGH',
    'DEFAULT'
);


ALTER TYPE todo.priority OWNER TO postgres;

--
-- Name: create_todo_dto; Type: TYPE; Schema: todo; Owner: postgres
--

CREATE TYPE todo.create_todo_dto AS (
	title character varying,
	description character varying,
	priority todo.priority,
	category_id integer,
	due_date date
);


ALTER TYPE todo.create_todo_dto OWNER TO postgres;

--
-- Name: update_todo_dto; Type: TYPE; Schema: todo; Owner: postgres
--

CREATE TYPE todo.update_todo_dto AS (
	id integer,
	title character varying,
	description character varying,
	priority todo.priority,
	category_id integer,
	due_date date,
	is_done boolean
);


ALTER TYPE todo.update_todo_dto OWNER TO postgres;

--
-- Name: auth_login(character varying, character varying); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.auth_login(uname character varying, pswd character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    t_authuser record;
begin
    select * into t_authuser from auth.authuser where username = lower(uname);
    if not FOUND or not utils.match_password(pswd, t_authuser.password) then
        raise exception 'Bad credentials';
    end if;


    -- return row_to_json(t_authuser)::text;
    return json_build_object(
            'id', t_authuser.id,
            'username', t_authuser.username,
            'role', t_authuser.role,
            'language', t_authuser.language,
            'created_date', t_authuser.created_at
        )::text;
end
$$;


ALTER FUNCTION auth.auth_login(uname character varying, pswd character varying) OWNER TO postgres;

--
-- Name: auth_register(character varying, character varying); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.auth_register(uname character varying, pswd character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newID       int;
begin

    if exists(select * from auth.authuser a where a.username ilike uname) then
        raise exception 'Username "%" already taken', uname;
    end if;

    insert into auth.authuser (username, password)
    values (uname, utils.encode_password(pswd))
    returning id into newID;
    return newID;
end
$$;


ALTER FUNCTION auth.auth_register(uname character varying, pswd character varying) OWNER TO postgres;

--
-- Name: hasrole(auth.authrole, integer); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.hasrole(role auth.authrole, userid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_authuser record;
begin
    select * into t_authuser from auth.authuser a where a.id = userid;
    if FOUND then
        return t_authuser.role = role;
    else
        return false;
    end if;
end
$$;


ALTER FUNCTION auth.hasrole(role auth.authrole, userid integer) OWNER TO postgres;

--
-- Name: isactive(integer); Type: PROCEDURE; Schema: auth; Owner: postgres
--

CREATE PROCEDURE auth.isactive(IN userid integer)
    LANGUAGE plpgsql
    AS $$
begin
    if not exists(select *  from auth.authuser a where a.id = userid) then
        raise 'User not found : "%"',userid;
    end if;
end
$$;


ALTER PROCEDURE auth.isactive(IN userid integer) OWNER TO postgres;

--
-- Name: create_category(character varying, integer); Type: FUNCTION; Schema: category; Owner: postgres
--

CREATE FUNCTION category.create_category(title character varying, userid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newID      int;
begin
    call auth.isactive(userid);
    
    insert into category.category (title, user_id)
    values (title, userid)
    returning id into newID;

    return newID;
end
$$;


ALTER FUNCTION category.create_category(title character varying, userid integer) OWNER TO postgres;

--
-- Name: delete_category(integer, integer); Type: FUNCTION; Schema: category; Owner: postgres
--

CREATE FUNCTION category.delete_category(categoryid integer, userid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_category record;
begin

    call auth.isactive(userid);

    select * into t_category from category.category c where c.id = categoryid;

    if not FOUND then
        raise exception 'Category not found : "%"',categoryid;
    end if;

    if auth.hasrole('ADMIN', userid) or userid = t_category.user_id then
        delete from category.category c where c.id = categoryid;
    else
        raise exception 'Permission denied';
    end if;

    return true;
end
$$;


ALTER FUNCTION category.delete_category(categoryid integer, userid integer) OWNER TO postgres;

--
-- Name: create_todo(text, integer); Type: FUNCTION; Schema: todo; Owner: postgres
--

CREATE FUNCTION todo.create_todo(dataparam text, userid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newID      int;
    dataJson   json;
    t_category record;
    dto        todo.create_todo_dto;
begin
    call auth.isactive(userid);
    
    if dataparam is null then
        raise exception 'Dataparam invalid';
    end if;

    dataJson := dataparam::json;

    dto.title := dataJson ->> 'title';
    dto.description := dataJson ->> 'description';
    dto.category_id := dataJson ->> 'category_id';
    dto.priority := coalesce(dataJson ->> 'priority', 'DEFAULT');
    dto.due_date := dataJson ->> 'due_date';

    select * into t_category from category.category c where c.id = dto.category_id;

    if not FOUND then
        raise exception 'Category not Found "%"',dto.category_id;
    end if;

    if t_category.user_id <> userid then
        raise exception 'Permission denied';
    end if;

    insert into todo.todo (title, description, priority, category_id, due_date)
    values (dto.title, dto.description, dto.priority, dto.category_id, dto.due_date)
    returning id into newID;
    return newID;
end
$$;


ALTER FUNCTION todo.create_todo(dataparam text, userid integer) OWNER TO postgres;

--
-- Name: update_todo(character varying, integer); Type: FUNCTION; Schema: todo; Owner: postgres
--

CREATE FUNCTION todo.update_todo(dataparam character varying, userid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    t_todo     record;
    t_category record;
    dataJson   json;
    dto        todo.update_todo_dto;
begin
    call auth.isactive(userid);

    if dataparam is null then
        raise exception 'Dataparam invalid';
    end if;

    dataJson := dataparam::json;
    dto.id := dataJson ->> 'id';

    select * into t_todo from todo.todo t where t.id = dto.id;

    if not FOUND then
        raise exception 'Todo not found "%"',dto.id;
    end if;

    select * into t_category from category.category c where c.id = t_todo.category_id;
    
    if not FOUND or t_category.user_id <> userid then
        raise exception 'Permission denied';
    end if;


    dto.title := coalesce(dataJson ->> 'title', t_todo.title);
    dto.description := coalesce(dataJson ->> 'description', t_todo.description);
    dto.priority := coalesce(dataJson ->> 'priority', t_todo.priority::text);
    dto.due_date := coalesce(dataJson ->> 'due_date', t_todo.due_date::text);
    dto.is_done := coalesce(dataJson ->> 'is_done', t_todo.is_done::text);


    update todo.todo
    set title       = dto.title,
        description = dto.description,
        priority    = dto.priority,
        due_date    = dto.due_date,
        is_done     = dto.is_done
    where id = dto.id;

    return true;

end
$$;


ALTER FUNCTION todo.update_todo(dataparam character varying, userid integer) OWNER TO postgres;

--
-- Name: user_todos_by_category(integer); Type: FUNCTION; Schema: todo; Owner: postgres
--

CREATE FUNCTION todo.user_todos_by_category(userid integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
begin
    call auth.isactive(userid);

    return (select json_agg(json_build_object(
            'category_id', category_id,
            'category_name', category_name,
            'user_id', user_id,
            'todos', todos))
            from (select t.category_id,
                         c.title  category_name,
                         c.user_id,
                         json_agg(
                                 json_build_object(
                                         'id', t.id,
                                         'title', t.title,
                                         'description', t.description,
                                         'due_date', t.due_date,
                                         'priority', t.priority,
                                         'is_done', t.is_done,
                                         'created_at', t.created_at
                                     )
                             ) as todos
                  from todo t
                           inner join category.category c on c.id = t.category_id
                  where c.user_id = userid
                  group by t.category_id, c.title, c.user_id) as category_details)::text;
end
$$;


ALTER FUNCTION todo.user_todos_by_category(userid integer) OWNER TO postgres;

--
-- Name: encode_password(character varying); Type: FUNCTION; Schema: utils; Owner: postgres
--

CREATE FUNCTION utils.encode_password(raw_password character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
begin
    return utils.crypt(raw_password, utils.gen_salt('bf', 4));
end
$$;


ALTER FUNCTION utils.encode_password(raw_password character varying) OWNER TO postgres;

--
-- Name: match_password(character varying, character varying); Type: FUNCTION; Schema: utils; Owner: postgres
--

CREATE FUNCTION utils.match_password(raw_password character varying, encoded_password character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    return encoded_password = utils.crypt(raw_password, encoded_password);
end
$$;


ALTER FUNCTION utils.match_password(raw_password character varying, encoded_password character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: authuser; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.authuser (
    id integer NOT NULL,
    username character varying NOT NULL,
    password character varying NOT NULL,
    role auth.authrole DEFAULT 'USER'::auth.authrole NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    language auth.language DEFAULT 'UZ'::auth.language NOT NULL,
    CONSTRAINT username_length_valid_check CHECK ((length((username)::text) > 4))
);


ALTER TABLE auth.authuser OWNER TO postgres;

--
-- Name: authuser_id_seq; Type: SEQUENCE; Schema: auth; Owner: postgres
--

CREATE SEQUENCE auth.authuser_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.authuser_id_seq OWNER TO postgres;

--
-- Name: authuser_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: postgres
--

ALTER SEQUENCE auth.authuser_id_seq OWNED BY auth.authuser.id;


--
-- Name: category; Type: TABLE; Schema: category; Owner: postgres
--

CREATE TABLE category.category (
    id integer NOT NULL,
    title character varying NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE category.category OWNER TO postgres;

--
-- Name: category_id_seq; Type: SEQUENCE; Schema: category; Owner: postgres
--

CREATE SEQUENCE category.category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE category.category_id_seq OWNER TO postgres;

--
-- Name: category_id_seq; Type: SEQUENCE OWNED BY; Schema: category; Owner: postgres
--

ALTER SEQUENCE category.category_id_seq OWNED BY category.category.id;


--
-- Name: todo; Type: TABLE; Schema: todo; Owner: postgres
--

CREATE TABLE todo.todo (
    id integer NOT NULL,
    title character varying,
    description character varying,
    priority todo.priority DEFAULT 'DEFAULT'::todo.priority NOT NULL,
    category_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    due_date date,
    is_done boolean DEFAULT false
);


ALTER TABLE todo.todo OWNER TO postgres;

--
-- Name: todo_id_seq; Type: SEQUENCE; Schema: todo; Owner: postgres
--

CREATE SEQUENCE todo.todo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE todo.todo_id_seq OWNER TO postgres;

--
-- Name: todo_id_seq; Type: SEQUENCE OWNED BY; Schema: todo; Owner: postgres
--

ALTER SEQUENCE todo.todo_id_seq OWNED BY todo.todo.id;


--
-- Name: authuser id; Type: DEFAULT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.authuser ALTER COLUMN id SET DEFAULT nextval('auth.authuser_id_seq'::regclass);


--
-- Name: category id; Type: DEFAULT; Schema: category; Owner: postgres
--

ALTER TABLE ONLY category.category ALTER COLUMN id SET DEFAULT nextval('category.category_id_seq'::regclass);


--
-- Name: todo id; Type: DEFAULT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todo ALTER COLUMN id SET DEFAULT nextval('todo.todo_id_seq'::regclass);


--
-- Data for Name: authuser; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.authuser (id, username, password, role, created_at, language) FROM stdin;
\.
COPY auth.authuser (id, username, password, role, created_at, language) FROM '$$PATH$$/3424.dat';

--
-- Data for Name: category; Type: TABLE DATA; Schema: category; Owner: postgres
--

COPY category.category (id, title, user_id, created_at) FROM stdin;
\.
COPY category.category (id, title, user_id, created_at) FROM '$$PATH$$/3426.dat';

--
-- Data for Name: todo; Type: TABLE DATA; Schema: todo; Owner: postgres
--

COPY todo.todo (id, title, description, priority, category_id, created_at, due_date, is_done) FROM stdin;
\.
COPY todo.todo (id, title, description, priority, category_id, created_at, due_date, is_done) FROM '$$PATH$$/3428.dat';

--
-- Name: authuser_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: postgres
--

SELECT pg_catalog.setval('auth.authuser_id_seq', 6, true);


--
-- Name: category_id_seq; Type: SEQUENCE SET; Schema: category; Owner: postgres
--

SELECT pg_catalog.setval('category.category_id_seq', 8, true);


--
-- Name: todo_id_seq; Type: SEQUENCE SET; Schema: todo; Owner: postgres
--

SELECT pg_catalog.setval('todo.todo_id_seq', 12, true);


--
-- Name: authuser authuser_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.authuser
    ADD CONSTRAINT authuser_pkey PRIMARY KEY (id);


--
-- Name: authuser authuser_username_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.authuser
    ADD CONSTRAINT authuser_username_key UNIQUE (username);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: category; Owner: postgres
--

ALTER TABLE ONLY category.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (id);


--
-- Name: todo todo_pkey; Type: CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todo
    ADD CONSTRAINT todo_pkey PRIMARY KEY (id);


--
-- Name: category category_user_id_fkey; Type: FK CONSTRAINT; Schema: category; Owner: postgres
--

ALTER TABLE ONLY category.category
    ADD CONSTRAINT category_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.authuser(id) ON DELETE CASCADE;


--
-- Name: todo todo_category_id_fkey; Type: FK CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todo
    ADD CONSTRAINT todo_category_id_fkey FOREIGN KEY (category_id) REFERENCES category.category(id);


--
-- PostgreSQL database dump complete
--

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          