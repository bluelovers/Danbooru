--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

--
-- Name: post_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE post_status AS ENUM (
    'deleted',
    'flagged',
    'pending',
    'active'
);


--
-- Name: pools_posts_delete_trg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pools_posts_delete_trg() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				BEGIN
					UPDATE pools SET post_count = post_count - 1 WHERE id = OLD.pool_id;
					RETURN OLD;
				END;
				$$;


--
-- Name: pools_posts_insert_trg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pools_posts_insert_trg() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
				BEGIN
					UPDATE pools SET post_count = post_count + 1 WHERE id = NEW.pool_id;
					RETURN NEW;
				END;
				$$;


--
-- Name: trg_posts_tags__delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts_tags__delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        UPDATE tags SET post_count = post_count - 1 WHERE tags.id = OLD.tag_id;
        RETURN OLD;
      END;
      $$;


--
-- Name: trg_posts_tags__insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts_tags__insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        UPDATE tags SET post_count = post_count + 1 WHERE tags.id = NEW.tag_id;
        RETURN NEW;
      END;
      $$;


--
-- Name: danbooru; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION danbooru (
    PARSER = testparser );

ALTER TEXT SEARCH CONFIGURATION danbooru
    ADD MAPPING FOR word WITH simple;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: advertisement_hits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE advertisement_hits (
    id integer NOT NULL,
    advertisement_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ip_addr inet
);


--
-- Name: advertisement_hits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE advertisement_hits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: advertisement_hits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE advertisement_hits_id_seq OWNED BY advertisement_hits.id;


--
-- Name: advertisement_hits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('advertisement_hits_id_seq', 1, false);


--
-- Name: advertisements; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE advertisements (
    id integer NOT NULL,
    referral_url character varying(255) NOT NULL,
    ad_type character varying(255) NOT NULL,
    status character varying(255) NOT NULL,
    hit_count integer DEFAULT 0 NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    is_work_safe boolean DEFAULT false NOT NULL,
    file_name character varying(255),
    created_at timestamp without time zone
);


--
-- Name: advertisements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE advertisements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: advertisements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE advertisements_id_seq OWNED BY advertisements.id;


--
-- Name: advertisements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('advertisements_id_seq', 7, true);


--
-- Name: artist_urls; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE artist_urls (
    id integer NOT NULL,
    artist_id integer NOT NULL,
    url text NOT NULL,
    normalized_url text NOT NULL
);


--
-- Name: artist_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE artist_urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: artist_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE artist_urls_id_seq OWNED BY artist_urls.id;


--
-- Name: artist_urls_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('artist_urls_id_seq', 1, false);


--
-- Name: artist_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE artist_versions (
    id integer NOT NULL,
    artist_id integer,
    version integer DEFAULT 0 NOT NULL,
    alias_id integer,
    group_id integer,
    name text,
    updater_id integer,
    cached_urls text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    is_active boolean DEFAULT true NOT NULL,
    other_names_array text[],
    group_name character varying(255)
);


--
-- Name: artist_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE artist_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: artist_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE artist_versions_id_seq OWNED BY artist_versions.id;


--
-- Name: artist_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('artist_versions_id_seq', 1, false);


--
-- Name: artists; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE artists (
    id integer NOT NULL,
    alias_id integer,
    group_id integer,
    name text NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updater_id integer,
    version integer,
    is_active boolean DEFAULT true NOT NULL,
    other_names_array text[],
    group_name character varying(255)
);


--
-- Name: artists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE artists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: artists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE artists_id_seq OWNED BY artists.id;


--
-- Name: artists_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('artists_id_seq', 1, false);


--
-- Name: bans; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bans (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reason text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    banned_by integer NOT NULL,
    old_level integer
);


--
-- Name: bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bans_id_seq OWNED BY bans.id;


--
-- Name: bans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('bans_id_seq', 1, false);


--
-- Name: comment_votes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comment_votes (
    id integer NOT NULL,
    comment_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: comment_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comment_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: comment_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comment_votes_id_seq OWNED BY comment_votes.id;


--
-- Name: comment_votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('comment_votes_id_seq', 1, false);


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comments (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    post_id integer NOT NULL,
    user_id integer,
    body text NOT NULL,
    ip_addr inet NOT NULL,
    text_search_index tsvector,
    score integer DEFAULT 0 NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--
-- Name: comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('comments_id_seq', 1, false);


--
-- Name: dmails; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dmails (
    id integer NOT NULL,
    from_id integer NOT NULL,
    to_id integer NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    has_seen boolean DEFAULT false NOT NULL,
    parent_id integer
);


--
-- Name: dmails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE dmails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: dmails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE dmails_id_seq OWNED BY dmails.id;


--
-- Name: dmails_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('dmails_id_seq', 1, false);


--
-- Name: tag_subscriptions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tag_query text NOT NULL,
    cached_post_ids text DEFAULT ''::text NOT NULL,
    name character varying(255) DEFAULT 'General'::character varying NOT NULL,
    is_visible_on_profile boolean DEFAULT true NOT NULL
);


--
-- Name: favorite_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE favorite_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: favorite_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE favorite_tags_id_seq OWNED BY tag_subscriptions.id;


--
-- Name: favorite_tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('favorite_tags_id_seq', 1, false);


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE favorites (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE favorites_id_seq OWNED BY favorites.id;


--
-- Name: favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('favorites_id_seq', 1, false);


--
-- Name: flagged_post_details; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE flagged_post_details (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    post_id integer NOT NULL,
    reason text NOT NULL,
    user_id integer NOT NULL,
    is_resolved boolean NOT NULL
);


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE flagged_post_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE flagged_post_details_id_seq OWNED BY flagged_post_details.id;


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('flagged_post_details_id_seq', 1, false);


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE forum_posts (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    creator_id integer,
    parent_id integer,
    last_updated_by integer,
    is_sticky boolean DEFAULT false NOT NULL,
    response_count integer DEFAULT 0 NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: forum_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE forum_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: forum_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE forum_posts_id_seq OWNED BY forum_posts.id;


--
-- Name: forum_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('forum_posts_id_seq', 1, false);


--
-- Name: job_tasks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE job_tasks (
    id integer NOT NULL,
    task_type character varying(255) NOT NULL,
    status character varying(255) NOT NULL,
    status_message text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    data_as_json text DEFAULT '{}'::text NOT NULL,
    repeat_count integer DEFAULT 0 NOT NULL
);


--
-- Name: job_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE job_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: job_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE job_tasks_id_seq OWNED BY job_tasks.id;


--
-- Name: job_tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('job_tasks_id_seq', 1, false);


--
-- Name: mod_queue_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE mod_queue_posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL
);


--
-- Name: mod_queue_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE mod_queue_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: mod_queue_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE mod_queue_posts_id_seq OWNED BY mod_queue_posts.id;


--
-- Name: mod_queue_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('mod_queue_posts_id_seq', 1, false);


--
-- Name: note_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE note_versions (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    body text NOT NULL,
    version integer NOT NULL,
    ip_addr inet NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    note_id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer,
    text_search_index tsvector
);


--
-- Name: note_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE note_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: note_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE note_versions_id_seq OWNED BY note_versions.id;


--
-- Name: note_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('note_versions_id_seq', 1, false);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notes (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    ip_addr inet NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    post_id integer NOT NULL,
    body text NOT NULL,
    text_search_index tsvector
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notes_id_seq OWNED BY notes.id;


--
-- Name: notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('notes_id_seq', 1, false);


--
-- Name: pool_updates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pool_updates (
    id integer NOT NULL,
    pool_id integer NOT NULL,
    post_ids text DEFAULT ''::text NOT NULL,
    user_id integer,
    ip_addr inet,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: pool_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pool_updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pool_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pool_updates_id_seq OWNED BY pool_updates.id;


--
-- Name: pool_updates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('pool_updates_id_seq', 1, false);


--
-- Name: pools; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pools (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    is_public boolean DEFAULT false NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: pools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pools_id_seq OWNED BY pools.id;


--
-- Name: pools_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('pools_id_seq', 1, false);


--
-- Name: pools_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pools_posts (
    id integer NOT NULL,
    sequence integer DEFAULT 0 NOT NULL,
    pool_id integer NOT NULL,
    post_id integer NOT NULL,
    next_post_id integer,
    prev_post_id integer
);


--
-- Name: pools_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pools_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: pools_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pools_posts_id_seq OWNED BY pools_posts.id;


--
-- Name: pools_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('pools_posts_id_seq', 1, false);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    user_id integer,
    score integer DEFAULT 0 NOT NULL,
    source text NOT NULL,
    md5 text NOT NULL,
    last_commented_at timestamp without time zone,
    rating character(1) DEFAULT 'q'::bpchar NOT NULL,
    width integer,
    height integer,
    is_warehoused boolean DEFAULT false NOT NULL,
    ip_addr inet NOT NULL,
    cached_tags text DEFAULT ''::text NOT NULL,
    is_note_locked boolean DEFAULT false NOT NULL,
    fav_count integer DEFAULT 0 NOT NULL,
    file_ext text DEFAULT ''::text NOT NULL,
    last_noted_at timestamp without time zone,
    is_rating_locked boolean DEFAULT false NOT NULL,
    parent_id integer,
    has_children boolean DEFAULT false NOT NULL,
    status post_status DEFAULT 'active'::post_status NOT NULL,
    sample_width integer,
    sample_height integer,
    change_seq integer,
    approver_id integer,
    tags_index tsvector,
    general_tag_count integer DEFAULT 0 NOT NULL,
    artist_tag_count integer DEFAULT 0 NOT NULL,
    character_tag_count integer DEFAULT 0 NOT NULL,
    copyright_tag_count integer DEFAULT 0 NOT NULL,
    file_size integer
);


--
-- Name: post_change_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_change_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: post_change_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_change_seq OWNED BY posts.change_seq;


--
-- Name: post_change_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('post_change_seq', 1, false);


--
-- Name: post_tag_histories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_tag_histories (
    id integer NOT NULL,
    post_id integer NOT NULL,
    tags text NOT NULL,
    user_id integer,
    ip_addr inet NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    rating character(1),
    parent_id integer
);


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_tag_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_tag_histories_id_seq OWNED BY post_tag_histories.id;


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('post_tag_histories_id_seq', 1, false);


--
-- Name: post_votes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_votes (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    score integer DEFAULT 0 NOT NULL
);


--
-- Name: post_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: post_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_votes_id_seq OWNED BY post_votes.id;


--
-- Name: post_votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('post_votes_id_seq', 1, false);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('posts_id_seq', 1, false);


--
-- Name: posts_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts_tags (
    post_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: server_keys; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE server_keys (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    value text
);


--
-- Name: server_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE server_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: server_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE server_keys_id_seq OWNED BY server_keys.id;


--
-- Name: server_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('server_keys_id_seq', 2, true);


--
-- Name: table_data; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE table_data (
    name text NOT NULL,
    row_count integer NOT NULL
);


--
-- Name: tag_aliases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_aliases (
    id integer NOT NULL,
    name text NOT NULL,
    alias_id integer NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    creator_id integer
);


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tag_aliases_id_seq OWNED BY tag_aliases.id;


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('tag_aliases_id_seq', 1, false);


--
-- Name: tag_implications; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_implications (
    id integer NOT NULL,
    consequent_id integer NOT NULL,
    predicate_id integer NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    creator_id integer
);


--
-- Name: tag_implications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_implications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tag_implications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tag_implications_id_seq OWNED BY tag_implications.id;


--
-- Name: tag_implications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('tag_implications_id_seq', 1, false);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tags (
    id integer NOT NULL,
    name text NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    cached_related text DEFAULT '[]'::text NOT NULL,
    cached_related_expires_on timestamp without time zone DEFAULT now() NOT NULL,
    tag_type smallint DEFAULT 0 NOT NULL,
    is_ambiguous boolean DEFAULT false NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tags_id_seq OWNED BY tags.id;


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('tags_id_seq', 1, false);


--
-- Name: test_janitors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE test_janitors (
    id integer NOT NULL,
    user_id integer NOT NULL,
    test_promotion_date timestamp without time zone NOT NULL,
    promotion_date timestamp without time zone,
    original_level integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: test_janitors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE test_janitors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: test_janitors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE test_janitors_id_seq OWNED BY test_janitors.id;


--
-- Name: test_janitors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('test_janitors_id_seq', 1, false);


--
-- Name: user_blacklisted_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_blacklisted_tags (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tags text NOT NULL
);


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_blacklisted_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_blacklisted_tags_id_seq OWNED BY user_blacklisted_tags.id;


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('user_blacklisted_tags_id_seq', 1, false);


--
-- Name: user_records; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_records (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reported_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    is_positive boolean DEFAULT true NOT NULL,
    body text NOT NULL
);


--
-- Name: user_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: user_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_records_id_seq OWNED BY user_records.id;


--
-- Name: user_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('user_records_id_seq', 1, false);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    name text NOT NULL,
    password_hash text NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    email text DEFAULT ''::text NOT NULL,
    recent_tags text DEFAULT ''::text NOT NULL,
    invite_count integer DEFAULT 0 NOT NULL,
    always_resize_images boolean DEFAULT false NOT NULL,
    invited_by integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    last_logged_in_at timestamp without time zone DEFAULT now() NOT NULL,
    last_forum_topic_read_at timestamp without time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
    has_mail boolean DEFAULT false NOT NULL,
    receive_dmails boolean DEFAULT false NOT NULL,
    show_samples boolean,
    base_upload_limit integer,
    uploaded_tags text DEFAULT ''::text NOT NULL,
    enable_autocomplete boolean DEFAULT true NOT NULL,
    comment_threshold integer DEFAULT 0 NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('users_id_seq', 1, false);


--
-- Name: wiki_page_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_page_versions (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr inet NOT NULL,
    wiki_page_id integer NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE wiki_page_versions_id_seq OWNED BY wiki_page_versions.id;


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('wiki_page_versions_id_seq', 1, false);


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_pages (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr inet NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE wiki_pages_id_seq OWNED BY wiki_pages.id;


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('wiki_pages_id_seq', 1, false);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE advertisement_hits ALTER COLUMN id SET DEFAULT nextval('advertisement_hits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE advertisements ALTER COLUMN id SET DEFAULT nextval('advertisements_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE artist_urls ALTER COLUMN id SET DEFAULT nextval('artist_urls_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE artist_versions ALTER COLUMN id SET DEFAULT nextval('artist_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE artists ALTER COLUMN id SET DEFAULT nextval('artists_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE bans ALTER COLUMN id SET DEFAULT nextval('bans_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE comment_votes ALTER COLUMN id SET DEFAULT nextval('comment_votes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE dmails ALTER COLUMN id SET DEFAULT nextval('dmails_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE favorites ALTER COLUMN id SET DEFAULT nextval('favorites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE flagged_post_details ALTER COLUMN id SET DEFAULT nextval('flagged_post_details_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE forum_posts ALTER COLUMN id SET DEFAULT nextval('forum_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE job_tasks ALTER COLUMN id SET DEFAULT nextval('job_tasks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE mod_queue_posts ALTER COLUMN id SET DEFAULT nextval('mod_queue_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE note_versions ALTER COLUMN id SET DEFAULT nextval('note_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE notes ALTER COLUMN id SET DEFAULT nextval('notes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pool_updates ALTER COLUMN id SET DEFAULT nextval('pool_updates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pools ALTER COLUMN id SET DEFAULT nextval('pools_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE pools_posts ALTER COLUMN id SET DEFAULT nextval('pools_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE post_tag_histories ALTER COLUMN id SET DEFAULT nextval('post_tag_histories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE post_votes ALTER COLUMN id SET DEFAULT nextval('post_votes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: change_seq; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE posts ALTER COLUMN change_seq SET DEFAULT nextval('post_change_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE server_keys ALTER COLUMN id SET DEFAULT nextval('server_keys_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tag_aliases ALTER COLUMN id SET DEFAULT nextval('tag_aliases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tag_implications ALTER COLUMN id SET DEFAULT nextval('tag_implications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tag_subscriptions ALTER COLUMN id SET DEFAULT nextval('favorite_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tags ALTER COLUMN id SET DEFAULT nextval('tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE test_janitors ALTER COLUMN id SET DEFAULT nextval('test_janitors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE user_blacklisted_tags ALTER COLUMN id SET DEFAULT nextval('user_blacklisted_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE user_records ALTER COLUMN id SET DEFAULT nextval('user_records_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE wiki_page_versions ALTER COLUMN id SET DEFAULT nextval('wiki_page_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE wiki_pages ALTER COLUMN id SET DEFAULT nextval('wiki_pages_id_seq'::regclass);


--
-- Data for Name: advertisement_hits; Type: TABLE DATA; Schema: public; Owner: -
--

COPY advertisement_hits (id, advertisement_id, created_at, updated_at, ip_addr) FROM stdin;
\.


--
-- Data for Name: advertisements; Type: TABLE DATA; Schema: public; Owner: -
--

COPY advertisements (id, referral_url, ad_type, status, hit_count, width, height, is_work_safe, file_name, created_at) FROM stdin;
1	#	vertical	active	0	0	0	t		2010-01-14 00:00:00
2	#	horizontal	active	0	0	0	t		2010-01-14 00:00:00
\.


--
-- Data for Name: artist_urls; Type: TABLE DATA; Schema: public; Owner: -
--

COPY artist_urls (id, artist_id, url, normalized_url) FROM stdin;
\.


--
-- Data for Name: artist_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY artist_versions (id, artist_id, version, alias_id, group_id, name, updater_id, cached_urls, created_at, updated_at, is_active, other_names_array, group_name) FROM stdin;
\.


--
-- Data for Name: artists; Type: TABLE DATA; Schema: public; Owner: -
--

COPY artists (id, alias_id, group_id, name, updated_at, updater_id, version, is_active, other_names_array, group_name) FROM stdin;
\.


--
-- Data for Name: bans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY bans (id, user_id, reason, expires_at, banned_by, old_level) FROM stdin;
\.


--
-- Data for Name: comment_votes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY comment_votes (id, comment_id, user_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY comments (id, created_at, post_id, user_id, body, ip_addr, text_search_index, score) FROM stdin;
\.


--
-- Data for Name: dmails; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dmails (id, from_id, to_id, title, body, created_at, has_seen, parent_id) FROM stdin;
\.


--
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: -
--

COPY favorites (id, post_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: flagged_post_details; Type: TABLE DATA; Schema: public; Owner: -
--

COPY flagged_post_details (id, created_at, post_id, reason, user_id, is_resolved) FROM stdin;
\.


--
-- Data for Name: forum_posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY forum_posts (id, created_at, updated_at, title, body, creator_id, parent_id, last_updated_by, is_sticky, response_count, is_locked, text_search_index) FROM stdin;
\.


--
-- Data for Name: job_tasks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY job_tasks (id, task_type, status, status_message, created_at, updated_at, data_as_json, repeat_count) FROM stdin;
\.


--
-- Data for Name: mod_queue_posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY mod_queue_posts (id, user_id, post_id) FROM stdin;
\.


--
-- Data for Name: note_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY note_versions (id, created_at, updated_at, x, y, width, height, body, version, ip_addr, is_active, note_id, post_id, user_id, text_search_index) FROM stdin;
\.


--
-- Data for Name: notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY notes (id, created_at, updated_at, user_id, x, y, width, height, ip_addr, version, is_active, post_id, body, text_search_index) FROM stdin;
\.


--
-- Data for Name: pool_updates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY pool_updates (id, pool_id, post_ids, user_id, ip_addr, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pools; Type: TABLE DATA; Schema: public; Owner: -
--

COPY pools (id, name, created_at, updated_at, user_id, is_public, post_count, description, is_active) FROM stdin;
\.


--
-- Data for Name: pools_posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY pools_posts (id, sequence, pool_id, post_id, next_post_id, prev_post_id) FROM stdin;
\.


--
-- Data for Name: post_tag_histories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY post_tag_histories (id, post_id, tags, user_id, ip_addr, created_at, rating, parent_id) FROM stdin;
\.


--
-- Data for Name: post_votes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY post_votes (id, post_id, user_id, created_at, updated_at, score) FROM stdin;
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY posts (id, created_at, user_id, score, source, md5, last_commented_at, rating, width, height, is_warehoused, ip_addr, cached_tags, is_note_locked, fav_count, file_ext, last_noted_at, is_rating_locked, parent_id, has_children, status, sample_width, sample_height, change_seq, approver_id, tags_index, general_tag_count, artist_tag_count, character_tag_count, copyright_tag_count, file_size) FROM stdin;
\.


--
-- Data for Name: posts_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY posts_tags (post_id, tag_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY schema_migrations (version) FROM stdin;
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
20080927145957
20081024223856
20090115234541
20090116232357
20090123212834
20090206235125
20090208201752
20090213162021
20090311231530
20090325201544
20090413232155
20090414194158
20090415190409
20090415231149
20090415233201
20090415233433
20090417190214
20090420182044
20090420223213
20090513212828
20090626224131
20090731194244
20090814153842
20090911190142
20091005214649
20091008202216
20091111184953
20091204202920
20091207180016
20091207183021
20091207194347
20091207194743
20091207200342
20091210162259
20091223165824
20091223184825
\.


--
-- Data for Name: server_keys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY server_keys (id, name, value) FROM stdin;
1	session_secret_key	This should be at least 30 characters long
2	user_password_salt	choujin-steiner
\.


--
-- Data for Name: table_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY table_data (name, row_count) FROM stdin;
posts	0
users	0
non-explicit_posts	0
\.


--
-- Data for Name: tag_aliases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY tag_aliases (id, name, alias_id, is_pending, reason, creator_id) FROM stdin;
\.


--
-- Data for Name: tag_implications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY tag_implications (id, consequent_id, predicate_id, is_pending, reason, creator_id) FROM stdin;
\.


--
-- Data for Name: tag_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY tag_subscriptions (id, user_id, tag_query, cached_post_ids, name, is_visible_on_profile) FROM stdin;
\.


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY tags (id, name, post_count, cached_related, cached_related_expires_on, tag_type, is_ambiguous) FROM stdin;
\.


--
-- Data for Name: test_janitors; Type: TABLE DATA; Schema: public; Owner: -
--

COPY test_janitors (id, user_id, test_promotion_date, promotion_date, original_level, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_blacklisted_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY user_blacklisted_tags (id, user_id, tags) FROM stdin;
\.


--
-- Data for Name: user_records; Type: TABLE DATA; Schema: public; Owner: -
--

COPY user_records (id, user_id, reported_by, created_at, is_positive, body) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY users (id, name, password_hash, level, email, recent_tags, invite_count, always_resize_images, invited_by, created_at, last_logged_in_at, last_forum_topic_read_at, has_mail, receive_dmails, show_samples, base_upload_limit, uploaded_tags, enable_autocomplete, comment_threshold) FROM stdin;
\.


--
-- Data for Name: wiki_page_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY wiki_page_versions (id, created_at, updated_at, version, title, body, user_id, ip_addr, wiki_page_id, is_locked, text_search_index) FROM stdin;
\.


--
-- Data for Name: wiki_pages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY wiki_pages (id, created_at, updated_at, version, title, body, user_id, ip_addr, is_locked, text_search_index) FROM stdin;
\.


--
-- Name: advertisement_hits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY advertisement_hits
    ADD CONSTRAINT advertisement_hits_pkey PRIMARY KEY (id);


--
-- Name: advertisements_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY advertisements
    ADD CONSTRAINT advertisements_pkey PRIMARY KEY (id);


--
-- Name: artist_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artist_urls
    ADD CONSTRAINT artist_urls_pkey PRIMARY KEY (id);


--
-- Name: artist_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artist_versions
    ADD CONSTRAINT artist_versions_pkey PRIMARY KEY (id);


--
-- Name: artists_name_uniq; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_name_uniq UNIQUE (name);


--
-- Name: artists_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_pkey PRIMARY KEY (id);


--
-- Name: bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bans
    ADD CONSTRAINT bans_pkey PRIMARY KEY (id);


--
-- Name: comment_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comment_votes
    ADD CONSTRAINT comment_votes_pkey PRIMARY KEY (id);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: dmails_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_pkey PRIMARY KEY (id);


--
-- Name: favorite_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tag_subscriptions
    ADD CONSTRAINT favorite_tags_pkey PRIMARY KEY (id);


--
-- Name: favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: flagged_post_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY flagged_post_details
    ADD CONSTRAINT flagged_post_details_pkey PRIMARY KEY (id);


--
-- Name: forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);


--
-- Name: job_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY job_tasks
    ADD CONSTRAINT job_tasks_pkey PRIMARY KEY (id);


--
-- Name: mod_queue_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY mod_queue_posts
    ADD CONSTRAINT mod_queue_posts_pkey PRIMARY KEY (id);


--
-- Name: note_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT note_versions_pkey PRIMARY KEY (id);


--
-- Name: notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: pool_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pool_updates
    ADD CONSTRAINT pool_updates_pkey PRIMARY KEY (id);


--
-- Name: pools_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pools
    ADD CONSTRAINT pools_pkey PRIMARY KEY (id);


--
-- Name: pools_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_pkey PRIMARY KEY (id);


--
-- Name: post_tag_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT post_tag_histories_pkey PRIMARY KEY (id);


--
-- Name: post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: server_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY server_keys
    ADD CONSTRAINT server_keys_pkey PRIMARY KEY (id);


--
-- Name: table_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY table_data
    ADD CONSTRAINT table_data_pkey PRIMARY KEY (name);


--
-- Name: tag_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT tag_aliases_pkey PRIMARY KEY (id);


--
-- Name: tag_implications_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT tag_implications_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: test_janitors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY test_janitors
    ADD CONSTRAINT test_janitors_pkey PRIMARY KEY (id);


--
-- Name: user_blacklisted_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_blacklisted_tags
    ADD CONSTRAINT user_blacklisted_tags_pkey PRIMARY KEY (id);


--
-- Name: user_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_records
    ADD CONSTRAINT user_records_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wiki_page_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY wiki_page_versions
    ADD CONSTRAINT wiki_page_versions_pkey PRIMARY KEY (id);


--
-- Name: wiki_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT wiki_pages_pkey PRIMARY KEY (id);


--
-- Name: comments_text_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX comments_text_search_idx ON notes USING gin (text_search_index);


--
-- Name: forum_posts__parent_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX forum_posts__parent_id_idx ON forum_posts USING btree (parent_id) WHERE (parent_id IS NULL);


--
-- Name: forum_posts_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX forum_posts_search_idx ON forum_posts USING gin (text_search_index);


--
-- Name: idx_comments__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_comments__post ON comments USING btree (post_id);


--
-- Name: idx_favorites__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_favorites__post ON favorites USING btree (post_id);


--
-- Name: idx_favorites__user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_favorites__user ON favorites USING btree (user_id);


--
-- Name: idx_note_versions__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_note_versions__post ON note_versions USING btree (post_id);


--
-- Name: idx_notes__note; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_notes__note ON note_versions USING btree (note_id);


--
-- Name: idx_notes__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_notes__post ON notes USING btree (post_id);


--
-- Name: idx_post_tag_histories__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_post_tag_histories__post ON post_tag_histories USING btree (post_id);


--
-- Name: idx_posts__created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__created_at ON posts USING btree (created_at);


--
-- Name: idx_posts__last_commented_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__last_commented_at ON posts USING btree (last_commented_at) WHERE (last_commented_at IS NOT NULL);


--
-- Name: idx_posts__last_noted_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__last_noted_at ON posts USING btree (last_noted_at) WHERE (last_noted_at IS NOT NULL);


--
-- Name: idx_posts__md5; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_posts__md5 ON posts USING btree (md5);


--
-- Name: idx_posts__user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__user ON posts USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_posts_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts_parent_id ON posts USING btree (parent_id) WHERE (parent_id IS NOT NULL);


--
-- Name: idx_posts_tags__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts_tags__post ON posts_tags USING btree (post_id);


--
-- Name: idx_posts_tags__tag; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts_tags__tag ON posts_tags USING btree (tag_id);


--
-- Name: idx_tag_aliases__name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_tag_aliases__name ON tag_aliases USING btree (name);


--
-- Name: idx_tag_implications__child; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tag_implications__child ON tag_implications USING btree (predicate_id);


--
-- Name: idx_tag_implications__parent; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tag_implications__parent ON tag_implications USING btree (consequent_id);


--
-- Name: idx_tags__name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_tags__name ON tags USING btree (name);


--
-- Name: idx_tags__post_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tags__post_count ON tags USING btree (post_count);


--
-- Name: idx_users__name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_users__name ON users USING btree (lower(name));


--
-- Name: idx_wiki_page_versions__wiki_page; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_page_versions__wiki_page ON wiki_page_versions USING btree (wiki_page_id);


--
-- Name: idx_wiki_pages__title; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_wiki_pages__title ON wiki_pages USING btree (title);


--
-- Name: idx_wiki_pages__updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_pages__updated_at ON wiki_pages USING btree (updated_at);


--
-- Name: index_advertisement_hits_on_advertisement_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_advertisement_hits_on_advertisement_id ON advertisement_hits USING btree (advertisement_id);


--
-- Name: index_advertisement_hits_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_advertisement_hits_on_created_at ON advertisement_hits USING btree (created_at);


--
-- Name: index_artist_urls_on_artist_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_urls_on_artist_id ON artist_urls USING btree (artist_id);


--
-- Name: index_artist_urls_on_normalized_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_urls_on_normalized_url ON artist_urls USING btree (normalized_url);


--
-- Name: index_artist_urls_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_urls_on_url ON artist_urls USING btree (url);


--
-- Name: index_artist_versions_on_artist_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_versions_on_artist_id ON artist_versions USING btree (artist_id);


--
-- Name: index_artist_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_versions_on_updater_id ON artist_versions USING btree (updater_id);


--
-- Name: index_artists_on_other_names_array; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artists_on_other_names_array ON artists USING btree (other_names_array);


--
-- Name: index_bans_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bans_on_user_id ON bans USING btree (user_id);


--
-- Name: index_comment_votes_on_comment_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comment_votes_on_comment_id ON comment_votes USING btree (comment_id);


--
-- Name: index_comment_votes_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comment_votes_on_created_at ON comment_votes USING btree (created_at);


--
-- Name: index_comment_votes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comment_votes_on_user_id ON comment_votes USING btree (user_id);


--
-- Name: index_dmails_on_from_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_dmails_on_from_id ON dmails USING btree (from_id);


--
-- Name: index_dmails_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_dmails_on_parent_id ON dmails USING btree (parent_id);


--
-- Name: index_dmails_on_to_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_dmails_on_to_id ON dmails USING btree (to_id);


--
-- Name: index_flagged_post_details_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_flagged_post_details_on_post_id ON flagged_post_details USING btree (post_id);


--
-- Name: index_forum_posts_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_posts_on_updated_at ON forum_posts USING btree (updated_at);


--
-- Name: index_note_versions_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_note_versions_on_user_id ON note_versions USING btree (user_id);


--
-- Name: index_pool_updates_on_pool_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_pool_updates_on_pool_id ON pool_updates USING btree (pool_id);


--
-- Name: index_post_tag_histories_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_tag_histories_on_user_id ON post_tag_histories USING btree (user_id);


--
-- Name: index_post_votes_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_votes_on_created_at ON post_votes USING btree (created_at);


--
-- Name: index_post_votes_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_votes_on_post_id ON post_votes USING btree (post_id);


--
-- Name: index_post_votes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_votes_on_user_id ON post_votes USING btree (user_id);


--
-- Name: index_posts_on_change_seq; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_change_seq ON posts USING btree (change_seq);


--
-- Name: index_posts_on_file_size; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_file_size ON posts USING btree (file_size);


--
-- Name: index_posts_on_height; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_height ON posts USING btree (height);


--
-- Name: index_posts_on_source; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_source ON posts USING btree (source);


--
-- Name: index_posts_on_tags_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_tags_index ON posts USING gin (tags_index);


--
-- Name: index_posts_on_width; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_width ON posts USING btree (width);


--
-- Name: index_server_keys_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_server_keys_on_name ON server_keys USING btree (name);


--
-- Name: index_tag_subscriptions_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tag_subscriptions_on_name ON tag_subscriptions USING btree (name);


--
-- Name: index_tag_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tag_subscriptions_on_user_id ON tag_subscriptions USING btree (user_id);


--
-- Name: index_test_janitors_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_test_janitors_on_user_id ON test_janitors USING btree (user_id);


--
-- Name: index_user_blacklisted_tags_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_blacklisted_tags_on_user_id ON user_blacklisted_tags USING btree (user_id);


--
-- Name: notes_text_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX notes_text_search_idx ON notes USING gin (text_search_index);


--
-- Name: pools_posts_pool_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pools_posts_pool_id_idx ON pools_posts USING btree (pool_id);


--
-- Name: pools_posts_post_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pools_posts_post_id_idx ON pools_posts USING btree (post_id);


--
-- Name: pools_user_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pools_user_id_idx ON pools USING btree (user_id);


--
-- Name: post_status_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX post_status_idx ON posts USING btree (status) WHERE (status < 'active'::post_status);


--
-- Name: posts_mpixels; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX posts_mpixels ON posts USING btree (((((width * height))::numeric / 1000000.0)));


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: wiki_pages_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX wiki_pages_search_idx ON wiki_pages USING gin (text_search_index);


--
-- Name: pools_posts_delete_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_delete_trg
    BEFORE DELETE ON pools_posts
    FOR EACH ROW
    EXECUTE PROCEDURE pools_posts_delete_trg();


--
-- Name: pools_posts_insert_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_insert_trg
    BEFORE INSERT ON pools_posts
    FOR EACH ROW
    EXECUTE PROCEDURE pools_posts_insert_trg();


--
-- Name: trg_comment_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_comment_search_update
    BEFORE INSERT OR UPDATE ON comments
    FOR EACH ROW
    EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'body');


--
-- Name: trg_forum_post_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_forum_post_search_update
    BEFORE INSERT OR UPDATE ON forum_posts
    FOR EACH ROW
    EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'title', 'body');


--
-- Name: trg_note_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_note_search_update
    BEFORE INSERT OR UPDATE ON notes
    FOR EACH ROW
    EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'body');


--
-- Name: trg_posts_tags__delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__delete
    BEFORE DELETE ON posts_tags
    FOR EACH ROW
    EXECUTE PROCEDURE trg_posts_tags__delete();


--
-- Name: trg_posts_tags__insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__insert
    BEFORE INSERT ON posts_tags
    FOR EACH ROW
    EXECUTE PROCEDURE trg_posts_tags__insert();


--
-- Name: trg_posts_tags_index_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags_index_update
    BEFORE INSERT OR UPDATE ON posts
    FOR EACH ROW
    EXECUTE PROCEDURE tsvector_update_trigger('tags_index', 'public.danbooru', 'cached_tags');


--
-- Name: trg_wiki_page_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_wiki_page_search_update
    BEFORE INSERT OR UPDATE ON wiki_pages
    FOR EACH ROW
    EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'title', 'body');


--
-- Name: artist_urls_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artist_urls
    ADD CONSTRAINT artist_urls_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES artists(id) ON DELETE CASCADE;


--
-- Name: artists_alias_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_alias_id_fkey FOREIGN KEY (alias_id) REFERENCES artists(id) ON DELETE SET NULL;


--
-- Name: artists_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_group_id_fkey FOREIGN KEY (group_id) REFERENCES artists(id) ON DELETE SET NULL;


--
-- Name: artists_updater_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_updater_id_fkey FOREIGN KEY (updater_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: bans_banned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bans
    ADD CONSTRAINT bans_banned_by_fkey FOREIGN KEY (banned_by) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: bans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bans
    ADD CONSTRAINT bans_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: comment_votes_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comment_votes
    ADD CONSTRAINT comment_votes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE;


--
-- Name: comment_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comment_votes
    ADD CONSTRAINT comment_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: dmails_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_from_id_fkey FOREIGN KEY (from_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: dmails_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES dmails(id);


--
-- Name: dmails_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_to_id_fkey FOREIGN KEY (to_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: fk_comments__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT fk_comments__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_comments__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT fk_comments__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_favorites__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT fk_favorites__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_favorites__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT fk_favorites__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: fk_note_versions__note; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT fk_note_versions__note FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE;


--
-- Name: fk_note_versions__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT fk_note_versions__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_note_versions__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT fk_note_versions__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_notes__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notes
    ADD CONSTRAINT fk_notes__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_notes__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notes
    ADD CONSTRAINT fk_notes__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_post_tag_histories__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT fk_post_tag_histories__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_posts__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT fk_posts__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_posts_tags__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts_tags
    ADD CONSTRAINT fk_posts_tags__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_posts_tags__tag; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts_tags
    ADD CONSTRAINT fk_posts_tags__tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_aliases__alias; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT fk_tag_aliases__alias FOREIGN KEY (alias_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_implications__child; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT fk_tag_implications__child FOREIGN KEY (predicate_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_implications__parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT fk_tag_implications__parent FOREIGN KEY (consequent_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_wiki_page_versions__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_page_versions
    ADD CONSTRAINT fk_wiki_page_versions__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_wiki_page_versions__wiki_page; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_page_versions
    ADD CONSTRAINT fk_wiki_page_versions__wiki_page FOREIGN KEY (wiki_page_id) REFERENCES wiki_pages(id) ON DELETE CASCADE;


--
-- Name: fk_wiki_pages__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT fk_wiki_pages__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: flagged_post_details_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY flagged_post_details
    ADD CONSTRAINT flagged_post_details_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: flagged_post_details_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY flagged_post_details
    ADD CONSTRAINT flagged_post_details_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: forum_posts_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: forum_posts_last_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: forum_posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES forum_posts(id) ON DELETE CASCADE;


--
-- Name: mod_queue_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY mod_queue_posts
    ADD CONSTRAINT mod_queue_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: mod_queue_posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY mod_queue_posts
    ADD CONSTRAINT mod_queue_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: pool_updates_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pool_updates
    ADD CONSTRAINT pool_updates_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES pools(id) ON DELETE CASCADE;


--
-- Name: pools_posts_next_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_next_post_id_fkey FOREIGN KEY (next_post_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- Name: pools_posts_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES pools(id) ON DELETE CASCADE;


--
-- Name: pools_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: pools_posts_prev_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_prev_post_id_fkey FOREIGN KEY (prev_post_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- Name: pools_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools
    ADD CONSTRAINT pools_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: post_tag_histories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT post_tag_histories_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: post_votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: post_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: posts_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- Name: tag_aliases_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT tag_aliases_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: tag_implications_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT tag_implications_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: tag_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_subscriptions
    ADD CONSTRAINT tag_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: test_janitors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY test_janitors
    ADD CONSTRAINT test_janitors_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_blacklisted_tags_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_blacklisted_tags
    ADD CONSTRAINT user_blacklisted_tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_records_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_records
    ADD CONSTRAINT user_records_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_records
    ADD CONSTRAINT user_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

