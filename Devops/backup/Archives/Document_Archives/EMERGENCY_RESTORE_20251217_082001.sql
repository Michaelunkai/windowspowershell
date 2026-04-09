--
-- PostgreSQL database dump
--

\restrict MQpybRA58RRBkOrY5MH4ONgUqde74qoe4YDHcwDUUDJRukvpbYwRUC4Fvb48WFX

-- Dumped from database version 17.4 (Debian 17.4-1.pgdg120+2)
-- Dumped by pg_dump version 18.1 (Ubuntu 18.1-1.pgdg24.04+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS '';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: friendstatus; Type: TYPE; Schema: public; Owner: raz@tovtech.org
--

CREATE TYPE public.friendstatus AS ENUM (
    'PENDING',
    'ACCEPTED',
    'BLOCKED',
    'DECLINED'
);


ALTER TYPE public.friendstatus OWNER TO "raz@tovtech.org";

--
-- Name: audit_delete_fn(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.audit_delete_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "DeleteAuditLog" (table_name, operation, old_data, deleted_by, client_info)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD)::jsonb, current_user, inet_client_addr()::TEXT);
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.audit_delete_fn() OWNER TO "raz@tovtech.org";

--
-- Name: block_mass_delete(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.block_mass_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    delete_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO delete_count FROM old_table;
    IF delete_count > 5 THEN
        RAISE EXCEPTION 'MASS DELETE BLOCKED: Attempted to delete % rows from %. Maximum 5 rows allowed per transaction. Contact Michael Fedorovsky',
            delete_count, TG_TABLE_NAME;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.block_mass_delete() OWNER TO "raz@tovtech.org";

--
-- Name: block_truncate(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.block_truncate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'TRUNCATE BLOCKED on table %: Contact Michael Fedorovsky for authorization', TG_TABLE_NAME;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.block_truncate() OWNER TO "raz@tovtech.org";

--
-- Name: notify_game_request_change(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.notify_game_request_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
notification_channel TEXT := 'game_requests';
payload JSON;
BEGIN
payload := json_build_object(
'event', TG_OP,
'id', NEW.id,
'sender_user_id', NEW.sender_user_id,
'recipient_user_id', NEW.recipient_user_id,
'game_id', NEW.game_id,
'status', NEW.status,
'message', NEW.message,
'created_at', NEW.created_at
);
PERFORM pg_notify(notification_channel, payload::text);
RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_game_request_change() OWNER TO "raz@tovtech.org";

--
-- Name: notify_game_request_event_persistent(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.notify_game_request_event_persistent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
notification_payload JSONB;
BEGIN
IF (TG_OP = 'INSERT') THEN
notification_payload = to_jsonb(NEW);
ELSEIF (TG_OP = 'UPDATE') THEN
notification_payload = to_jsonb(NEW);
END IF;

-- Store the notification in the database for persistence
INSERT INTO Notifications (user_id, type, message)
VALUES (notification_payload->>'recipient_user_id', TG_OP, notification_payload);

-- Send a NOTIFY for real-time delivery
PERFORM pg_notify(
    'game_requests',
    json_build_object(
        'recipient_user_id', notification_payload->>'recipient_user_id',
        'event', TG_OP,
        'payload', notification_payload
    )::text
);

RETURN NEW;

END;
$$;


ALTER FUNCTION public.notify_game_request_event_persistent() OWNER TO "raz@tovtech.org";

--
-- Name: set_end_time_default(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.set_end_time_default() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   -- Check if end_time is NOT already set.
   -- This allows for an explicit end_time to be provided if needed.
   IF NEW.end_time IS NULL THEN
      -- Sets the end_time to start_time plus a 1-hour interval.
      NEW.end_time = NEW.start_time + INTERVAL '1 hour';
   END IF;
   RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_end_time_default() OWNER TO "raz@tovtech.org";

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: raz@tovtech.org
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   -- Explicitly get the current time and convert it to UTC
   NEW.updated_at = CURRENT_TIMESTAMP AT TIME ZONE 'IDT';
   RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO "raz@tovtech.org";

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: BackupLog; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."BackupLog" (
    id integer NOT NULL,
    backup_time timestamp without time zone DEFAULT now(),
    backup_type character varying(50),
    backup_location text,
    row_counts jsonb,
    status character varying(20) DEFAULT 'success'::character varying
);


ALTER TABLE public."BackupLog" OWNER TO "raz@tovtech.org";

--
-- Name: BackupLog_id_seq; Type: SEQUENCE; Schema: public; Owner: raz@tovtech.org
--

CREATE SEQUENCE public."BackupLog_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."BackupLog_id_seq" OWNER TO "raz@tovtech.org";

--
-- Name: BackupLog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: raz@tovtech.org
--

ALTER SEQUENCE public."BackupLog_id_seq" OWNED BY public."BackupLog".id;


--
-- Name: ConnectionAuditLog; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."ConnectionAuditLog" (
    id integer NOT NULL,
    connection_time timestamp without time zone DEFAULT now(),
    username character varying(100),
    client_addr text,
    application_name text
);


ALTER TABLE public."ConnectionAuditLog" OWNER TO "raz@tovtech.org";

--
-- Name: ConnectionAuditLog_id_seq; Type: SEQUENCE; Schema: public; Owner: raz@tovtech.org
--

CREATE SEQUENCE public."ConnectionAuditLog_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."ConnectionAuditLog_id_seq" OWNER TO "raz@tovtech.org";

--
-- Name: ConnectionAuditLog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: raz@tovtech.org
--

ALTER SEQUENCE public."ConnectionAuditLog_id_seq" OWNED BY public."ConnectionAuditLog".id;


--
-- Name: DeleteAuditLog; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."DeleteAuditLog" (
    id integer NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(50) NOT NULL,
    old_data jsonb,
    deleted_by character varying(100) DEFAULT CURRENT_USER,
    deleted_at timestamp without time zone DEFAULT now(),
    row_count integer DEFAULT 1,
    client_info text,
    transaction_id bigint DEFAULT txid_current()
);


ALTER TABLE public."DeleteAuditLog" OWNER TO "raz@tovtech.org";

--
-- Name: DeleteAuditLog_id_seq; Type: SEQUENCE; Schema: public; Owner: raz@tovtech.org
--

CREATE SEQUENCE public."DeleteAuditLog_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."DeleteAuditLog_id_seq" OWNER TO "raz@tovtech.org";

--
-- Name: DeleteAuditLog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: raz@tovtech.org
--

ALTER SEQUENCE public."DeleteAuditLog_id_seq" OWNED BY public."DeleteAuditLog".id;


--
-- Name: EmailVerification; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."EmailVerification" (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    verification_code character varying(255) NOT NULL,
    is_verified boolean,
    expires_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."EmailVerification" OWNER TO "raz@tovtech.org";

--
-- Name: Game; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."Game" (
    id uuid NOT NULL,
    game_name character varying NOT NULL,
    category character varying,
    min_players integer,
    max_players integer,
    avg_session_duration integer,
    difficulty_level character varying,
    icon_url character varying,
    icon character varying,
    is_active boolean,
    game_site_url character varying
);


ALTER TABLE public."Game" OWNER TO "raz@tovtech.org";

--
-- Name: GameRequest; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."GameRequest" (
    id uuid NOT NULL,
    sender_user_id uuid NOT NULL,
    recipient_user_id uuid NOT NULL,
    game_id uuid NOT NULL,
    suggested_time timestamp without time zone,
    message text,
    status character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."GameRequest" OWNER TO "raz@tovtech.org";

--
-- Name: ProtectionStatus; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."ProtectionStatus" (
    id integer NOT NULL,
    protection_enabled boolean DEFAULT true,
    installed_at timestamp without time zone DEFAULT now(),
    last_verified timestamp without time zone DEFAULT now(),
    version character varying(20) DEFAULT '3.0'::character varying
);


ALTER TABLE public."ProtectionStatus" OWNER TO "raz@tovtech.org";

--
-- Name: ProtectionStatus_id_seq; Type: SEQUENCE; Schema: public; Owner: raz@tovtech.org
--

CREATE SEQUENCE public."ProtectionStatus_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."ProtectionStatus_id_seq" OWNER TO "raz@tovtech.org";

--
-- Name: ProtectionStatus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: raz@tovtech.org
--

ALTER SEQUENCE public."ProtectionStatus_id_seq" OWNED BY public."ProtectionStatus".id;


--
-- Name: ScheduledSession; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."ScheduledSession" (
    id uuid NOT NULL,
    game_id uuid NOT NULL,
    organizer_user_id uuid NOT NULL,
    second_player_id uuid NOT NULL,
    scheduled_date date,
    start_time time without time zone,
    end_time time without time zone,
    timezone character varying,
    status character varying,
    session_id uuid NOT NULL,
    session_type character varying,
    max_participants integer,
    description text,
    meeting_link character varying,
    reminder_sent boolean DEFAULT false,
    game_site_url character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."ScheduledSession" OWNER TO "raz@tovtech.org";

--
-- Name: User; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."User" (
    id uuid NOT NULL,
    email character varying(255),
    discord_id character varying(255),
    username character varying NOT NULL,
    discord_username character varying NOT NULL,
    hashed_password character varying,
    verified boolean,
    in_community boolean,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    avatar_url character varying,
    role character varying
);


ALTER TABLE public."User" OWNER TO "raz@tovtech.org";

--
-- Name: UserAvailability; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."UserAvailability" (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    day_of_week character varying NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    is_recurring boolean,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."UserAvailability" OWNER TO "raz@tovtech.org";

--
-- Name: UserFriends; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."UserFriends" (
    id uuid NOT NULL,
    sender_user_id uuid NOT NULL,
    recipient_user_id uuid NOT NULL,
    message text,
    status public.friendstatus NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."UserFriends" OWNER TO "raz@tovtech.org";

--
-- Name: UserGamePreference; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."UserGamePreference" (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    game_id uuid NOT NULL
);


ALTER TABLE public."UserGamePreference" OWNER TO "raz@tovtech.org";

--
-- Name: UserNotifications; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."UserNotifications" (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    title character varying NOT NULL,
    message character varying NOT NULL,
    is_read boolean,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."UserNotifications" OWNER TO "raz@tovtech.org";

--
-- Name: UserProfile; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."UserProfile" (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    bio character varying(64),
    avatar_url character varying(64),
    language character varying(64),
    timezone character varying(64),
    communication_preferences character varying(64),
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."UserProfile" OWNER TO "raz@tovtech.org";

--
-- Name: UserSession; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public."UserSession" (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    session_token uuid NOT NULL,
    expires_at timestamp without time zone,
    last_activity timestamp without time zone,
    user_agent text,
    ip_address character varying
);


ALTER TABLE public."UserSession" OWNER TO "raz@tovtech.org";

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO "raz@tovtech.org";

--
-- Name: auditlog; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public.auditlog (
    id integer NOT NULL,
    event_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    table_name character varying(255),
    operation character varying(50),
    affected_rows integer,
    user_account character varying(255),
    user_ip inet,
    error_details text,
    session_id character varying(255)
);


ALTER TABLE public.auditlog OWNER TO "raz@tovtech.org";

--
-- Name: auditlog_id_seq; Type: SEQUENCE; Schema: public; Owner: raz@tovtech.org
--

CREATE SEQUENCE public.auditlog_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auditlog_id_seq OWNER TO "raz@tovtech.org";

--
-- Name: auditlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: raz@tovtech.org
--

ALTER SEQUENCE public.auditlog_id_seq OWNED BY public.auditlog.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: raz@tovtech.org
--

CREATE TABLE public.password_reset_tokens (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    token character varying(256) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    used boolean DEFAULT false
);


ALTER TABLE public.password_reset_tokens OWNER TO "raz@tovtech.org";

--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: raz@tovtech.org
--

CREATE SEQUENCE public.password_reset_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.password_reset_tokens_id_seq OWNER TO "raz@tovtech.org";

--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: raz@tovtech.org
--

ALTER SEQUENCE public.password_reset_tokens_id_seq OWNED BY public.password_reset_tokens.id;


--
-- Name: BackupLog id; Type: DEFAULT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."BackupLog" ALTER COLUMN id SET DEFAULT nextval('public."BackupLog_id_seq"'::regclass);


--
-- Name: ConnectionAuditLog id; Type: DEFAULT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ConnectionAuditLog" ALTER COLUMN id SET DEFAULT nextval('public."ConnectionAuditLog_id_seq"'::regclass);


--
-- Name: DeleteAuditLog id; Type: DEFAULT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."DeleteAuditLog" ALTER COLUMN id SET DEFAULT nextval('public."DeleteAuditLog_id_seq"'::regclass);


--
-- Name: ProtectionStatus id; Type: DEFAULT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ProtectionStatus" ALTER COLUMN id SET DEFAULT nextval('public."ProtectionStatus_id_seq"'::regclass);


--
-- Name: auditlog id; Type: DEFAULT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.auditlog ALTER COLUMN id SET DEFAULT nextval('public.auditlog_id_seq'::regclass);


--
-- Name: password_reset_tokens id; Type: DEFAULT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.password_reset_tokens ALTER COLUMN id SET DEFAULT nextval('public.password_reset_tokens_id_seq'::regclass);


--
-- Data for Name: BackupLog; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."BackupLog" (id, backup_time, backup_type, backup_location, row_counts, status) FROM stdin;
1	2025-12-02 18:38:41.597593	protection_installed	\N	\N	success
2	2025-12-02 18:42:20.730808	local_auto	/opt/tovplay_backups/local/backup_local_20251202_184220.sql	\N	success
3	2025-12-03 00:00:02.349825	auto_6h	\N	\N	success
\.


--
-- Data for Name: ConnectionAuditLog; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."ConnectionAuditLog" (id, connection_time, username, client_addr, application_name) FROM stdin;
\.


--
-- Data for Name: DeleteAuditLog; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."DeleteAuditLog" (id, table_name, operation, old_data, deleted_by, deleted_at, row_count, client_info, transaction_id) FROM stdin;
1	UserFriends	DELETE	{"id": "7a0d2700-d2b9-4036-9ae9-34489f25f6e4", "status": "BLOCKED", "message": "TovPlay has blocked b", "created_at": "2025-12-15T09:13:53.496659", "updated_at": "2025-12-15T09:13:53.496669", "sender_user_id": "db27ffc7-7e19-4b0d-93c7-09d86e6b68f2", "recipient_user_id": "04ffeddb-f14c-4a7a-930b-b06175b3dc4d"}	raz@tovtech.org	2025-12-15 07:14:05.962703	1	84.110.46.174/32	48493
\.


--
-- Data for Name: EmailVerification; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."EmailVerification" (id, user_id, verification_code, is_verified, expires_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: Game; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."Game" (id, game_name, category, min_players, max_players, avg_session_duration, difficulty_level, icon_url, icon, is_active, game_site_url) FROM stdin;
497cd3f6-6ca6-40d5-9641-4ef108bd2a87	Animal Crossing	Relax & Socialize	1	8	45	easy	  https://1000logos.net/wp-content/uploads/2025/08/Animal-Crossing-Logo.png	LucideRabbit	t	https://animalcrossing.nintendo.com/
d356375b-650f-4b83-8c22-ebc8310a74ef	Chess	Strategic & Timeless	2	2	30	hard	https://images.chesscomfiles.com/uploads/v1/blog/291978.0ba48c8e.5000x5000o.b1dd3c4ba347.png	BrainCircuit	t	https://www.chess.com/
f7d77de5-d20e-4196-aa87-c4aa3f831d23	Stardew Valley	Farm & Befriend	1	4	90	medium	  https://stardewvalley.net/wp-content/uploads/2017/12/main_logo.png	Tractor	t	https://www.stardewvalley.net/
ef9026f8-ec75-4aef-84e8-01385c0f169c	Overwatch	Team-Based Shooter	6	12	20	hard	  https://1000logos.net/wp-content/uploads/2018/03/Overwatch-Logo.png	Shield	t	https://overwatch.blizzard.com/
b1370e74-8da6-4d15-bef9-c8163854cf93	Rocket League	Cars & Soccer	2	8	10	medium	  https://1000logos.net/wp-content/uploads/2021/12/Rocket-League-Logo.png	LucideRocket	t	https://www.rocketleague.com/
aa7a7e51-a947-4402-b46d-39b570e63ad5	League of Legends	MOBA	5	10	35	hard	  https://1000logos.net/wp-content/uploads/2020/09/League-of-Legends-Logo.png	Swords	t	https://www.leagueoflegends.com/
a05e3b94-7404-4c1b-819a-2ef5fee2ba27	Apex Legends	Squad-Based BR	3	60	25	hard	  https://1000logos.net/wp-content/uploads/2022/10/Apex-Legends-logo.png	Gamepad2	t	https://www.ea.com/games/apex-legends/
80315b4a-b6d2-492b-8b13-089b07feb31c	Fortnite	Build & Battle	1	100	25	medium	  https://1000logos.net/wp-content/uploads/2020/06/Fortnite-Logo-1.png	BuildingIcon	t	https://www.fortnite.com/
7ed96bfa-fd02-47d2-beca-39e73e689b4f	Minecraft	Build & Explore	1	20	60	medium	  https://1000logos.net/wp-content/uploads/2018/10/Minecraft-Logo.png	MountainIcon	t	https://www.minecraft.net/
75e3f4eb-5584-4542-a68a-c06fffa9f89c	Valorant	Tactical Shooter	5	10	40	hard	  https://1000logos.net/wp-content/uploads/2022/09/Valorant-Logo.png	Shield	t	https://playvalorant.com/
73bf3452-2201-4753-ac86-07f71c30e9d9	Fall Guys	Chaotic Fun	1	60	15	easy	  https://1000logos.net/wp-content/uploads/2023/05/Fall-Guys-Logo.png	Footprints	t	https://www.fallguys.com/
69755b4c-3f27-48a1-ba17-94fdc488577c	Among Us	Social Deception	4	15	20	easy	  https://1000logos.net/wp-content/uploads/2021/09/Among-Us-Logo.png	Ghost	t	https://www.innersloth.com/games/among-us/
\.


--
-- Data for Name: GameRequest; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."GameRequest" (id, sender_user_id, recipient_user_id, game_id, suggested_time, message, status, created_at, updated_at) FROM stdin;
d0c7bbc1-55c9-4cd4-830d-dcac69f040fd	35bdfe00-4545-46f6-ad25-df895f7d4ed9	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	75e3f4eb-5584-4542-a68a-c06fffa9f89c	2025-11-24 14:00:00	Hey! Would you be up for a game of Valorant?	pending	2025-11-18 10:58:06.69707	2025-11-18 10:58:06.697074
a8b24866-b6e2-47af-8a46-835a5b904c5d	35bdfe00-4545-46f6-ad25-df895f7d4ed9	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-19 09:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-18 11:02:23.441509	2025-11-18 11:02:23.441516
fc0c7753-93fb-45ef-b19f-dffa0b84deee	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 01:00:00	Hey, let's play today!	pending	2025-11-18 12:00:46.330486	2025-11-18 12:00:46.330489
32e9cdc2-eb49-4a64-a601-d71e96a2b8ff	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-24 02:00:00	Hey! Would you be up for a game of Chess?	Accepted	2025-11-18 12:47:18.212732	2025-11-18 12:37:37.027568
5d14bf99-6ea5-4b4a-ae86-704845b5101e	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	35bdfe00-4545-46f6-ad25-df895f7d4ed9	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-19 09:00:00	Hey! Would you be up for a game of Chess?	Accepted	2025-11-18 12:52:56.950873	2025-11-18 12:59:05.596342
bf37e40e-d9da-42eb-bcab-47e9d9c52376	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-20 21:00:00	Test message	pending	2025-11-20 10:15:04.142155	2025-11-20 10:15:04.142159
22bf7920-ed98-45cd-a1a2-fcbf70a5bebd	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-20 22:00:00	Test message for verification	pending	2025-11-20 10:21:45.096769	2025-11-20 10:21:45.096772
79ef469f-1e6a-4c14-a566-d00d7997c5b9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 06:00:00	Hey, let's play today!	pending	2025-11-20 10:40:00.601309	2025-11-20 10:40:00.601312
b1b60f8f-f99c-449e-8738-71b3ac0240a4	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 01:00:00	Test message for verification (fourth attempt)	pending	2025-11-20 10:42:48.743306	2025-11-20 10:42:48.743309
c3a8ff9b-2a12-4474-9cb1-610916eb8328	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 07:00:00	Hey, let's play today!	pending	2025-11-20 10:50:07.304364	2025-11-20 10:50:07.304368
e64a296a-172b-4b2b-94f2-1792309cef45	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 08:00:00	Hey, let's play today!	pending	2025-11-20 10:55:59.8417	2025-11-20 10:55:59.841703
35ec5862-5d51-4e88-a1de-ca325e8049d2	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 10:00:00	Hey, let's play today!	pending	2025-11-20 10:58:40.506613	2025-11-20 10:58:40.506616
85a586b8-7729-4333-8337-cfd7de4452a6	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 05:00:00	Test after implementing fetch on reconnect	pending	2025-11-20 11:00:00.944089	2025-11-20 11:00:00.944092
aa052ba2-94e0-4b21-9c4a-6996c561112b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 06:00:00	Test after useRef import	pending	2025-11-20 11:00:26.680506	2025-11-20 11:00:26.680509
9511735c-8660-4fe2-add8-9bcff977b6e6	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 11:00:00	Hey, let's play today!	pending	2025-11-20 12:33:10.010371	2025-11-20 12:33:10.010374
f6bc1c29-20a7-4863-8fbe-ef3b2b9cc229	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 12:00:00	Hey, let's play today!	pending	2025-11-20 12:51:14.515324	2025-11-20 12:51:14.515327
bfa933b9-b9fd-48f8-aad9-40e11dab843c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 14:00:00	Hey, let's play today!	pending	2025-11-20 15:44:51.024612	2025-11-20 15:44:51.024616
da37398c-5737-44f9-9118-f3f776846b5b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 16:00:00	Hey, let's play today!	pending	2025-11-21 09:55:56.950024	2025-11-21 09:55:56.950027
08a17cca-21c5-4675-abf7-ca6016ca84e4	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 17:00:00	Hey, let's play today!	pending	2025-11-21 22:08:16.015425	2025-11-21 22:08:16.015429
9fe381d4-b200-40af-a617-1e679a306967	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 11:00:00	Test game request	pending	2025-11-22 00:28:52.079219	2025-11-22 00:28:52.079221
e209f790-eeea-4f5f-bc0a-c5cc94c371d9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-25 00:00:00	Test game request	pending	2025-11-22 00:43:05.179798	2025-11-22 00:43:05.179801
ca8744ff-c842-4367-b03c-7d88c4b5b256	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-28 00:00:00	Test game request	pending	2025-11-22 00:45:26.670844	2025-11-22 00:45:26.670846
a63bd2ca-e5c5-4f1b-85ca-1068738f5b01	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-30 00:00:00	Test game request	pending	2025-11-22 00:47:50.724493	2025-11-22 00:47:50.724495
fae1e6d6-f833-4b09-ac95-5979e138c638	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-12 20:00:00	Hey, let's play today!	pending	2025-11-13 09:24:21.295526	2025-11-13 09:24:21.295529
8a885b0c-86f1-4533-92bb-bf36cb3b651d	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-12 21:00:00	Hey, let's play today!	pending	2025-11-13 09:35:53.295608	2025-11-13 09:35:53.295614
96b3aff1-c59b-4bb3-86ee-695686ee0cb8	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-12 22:00:00	Hey, let's play today!	pending	2025-11-13 09:36:36.291558	2025-11-13 09:36:36.291562
c7a6241b-ba93-47c9-87ef-8b5305890f4b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-12 23:00:00	Hey, let's play today!	pending	2025-11-13 09:38:12.628995	2025-11-13 09:38:12.628998
58fc03e1-f4de-4d8b-8f5e-9b98a86e9ae1	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 00:00:00	Hey, let's play today!	pending	2025-11-13 09:49:09.901207	2025-11-13 09:49:09.90121
3c9f4faa-547d-4522-8609-f40a34a7e22e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 01:00:00	Hey, let's play today!	pending	2025-11-13 09:52:36.776999	2025-11-13 09:52:36.777004
04bc93a7-6d44-4af2-ae57-cba25615b021	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 02:00:00	Hey, let's play today!	pending	2025-11-13 09:53:01.855445	2025-11-13 09:53:01.855448
881ecc48-2d33-45eb-bfcc-42d8daebb245	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 03:00:00	Hey, let's play today!	pending	2025-11-13 09:53:17.485073	2025-11-13 09:53:17.485077
da92ab59-82c5-4dfa-8d81-3dcacf6c8eee	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 04:00:00	Hey, let's play today!	pending	2025-11-13 09:53:54.807668	2025-11-13 09:53:54.807673
18282bf2-5e87-4e92-9365-b397101c9c59	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 05:00:00	Hey, let's play today!	pending	2025-11-13 09:56:46.411942	2025-11-13 09:56:46.411945
25706620-81a4-4d20-b665-4d0c6994e0c1	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 06:00:00	Hey, let's play today!	pending	2025-11-13 09:57:31.810644	2025-11-13 09:57:31.810647
b359e9d6-c72d-468d-81b9-ebaceabd9b07	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 07:00:00	Hey, let's play today!	pending	2025-11-13 10:07:02.747703	2025-11-13 10:07:02.747706
b5b0bcec-b10f-49fa-8a4c-67492bc01f61	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 08:00:00	Hey, let's play today!	pending	2025-11-13 10:13:35.13247	2025-11-13 10:13:35.132473
12b92b92-8709-45d7-9859-75c8052e6d8f	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 09:00:00	Hey, let's play today!	pending	2025-11-13 10:17:40.336207	2025-11-13 10:17:40.33621
4c988093-4e2c-497b-a7ab-87ce3dca4d3b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 10:00:00	Hey, let's play today!	pending	2025-11-13 10:21:18.823439	2025-11-13 10:21:18.823442
7d81cf09-7d28-4f72-b7e0-92d5e35028bc	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 11:00:00	Hey, let's play today!	pending	2025-11-13 10:31:57.256494	2025-11-13 10:31:57.256497
1136af43-0609-4fc4-b252-ca542e5d1932	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 12:00:00	Hey, let's play today!	pending	2025-11-13 10:33:52.667414	2025-11-13 10:33:52.667417
27fbf355-a623-45fc-bb21-b48ef760821e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 13:00:00	Hey, let's play today!	pending	2025-11-13 10:37:05.099508	2025-11-13 10:37:05.099511
11d660ae-4533-4ad4-a8d5-163d31ec25af	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 14:00:00	Hey, let's play today!	pending	2025-11-13 10:39:34.967361	2025-11-13 10:39:34.967364
dcc9fd0b-ef7e-46ce-bfb7-5046211a96ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 15:00:00	Hey, let's play today!	pending	2025-11-13 10:51:51.782627	2025-11-13 10:51:51.78263
3eb44351-27f0-41cd-b3d7-e6c8cb283937	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 16:00:00	Hey, let's play today!	pending	2025-11-13 10:57:19.904147	2025-11-13 10:57:19.90415
fd5dd9ff-629d-4e0b-9be0-c0a753dd04a9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 17:00:00	Hey, let's play today!	pending	2025-11-13 11:02:01.173604	2025-11-13 11:02:01.173608
9b4fcb3a-109f-477f-8816-50be2529c75a	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 18:00:00	Hey, let's play today!	pending	2025-11-13 11:03:06.698016	2025-11-13 11:03:06.698025
15776b9a-beb1-4116-93cf-4e235f06294f	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 19:00:00	Hey, let's play today!	pending	2025-11-13 11:05:01.422029	2025-11-13 11:05:01.422032
f15064cd-1b07-4a14-b43a-ef28410579c0	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 20:00:00	Hey, let's play today!	pending	2025-11-13 11:06:12.843051	2025-11-13 11:06:12.843055
8dddf2e2-af7f-402a-883a-274354d44ea3	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 21:00:00	Hey, let's play today!	pending	2025-11-13 11:07:12.622198	2025-11-13 11:07:12.622201
35c628a9-e176-4ea4-8272-7d115fd579c8	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 22:00:00	Hey, let's play today!	pending	2025-11-13 11:10:35.972704	2025-11-13 11:10:35.972707
3c04778c-0c9f-4594-b60b-f84093393156	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 23:00:00	Hey, let's play today!	pending	2025-11-13 11:11:41.280971	2025-11-13 11:11:41.280975
902633ab-bf19-4d64-b502-c960364cac8c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 00:00:00	Hey, let's play today!	pending	2025-11-13 11:14:43.162747	2025-11-13 11:14:43.162754
cc6ccfd8-0123-4b32-9bea-c51e4044aa19	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 01:00:00	Hey, let's play today!	pending	2025-11-13 11:16:11.004707	2025-11-13 11:16:11.00471
1b3d404f-fbac-44db-b8cf-91e96c23d5fd	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 02:00:00	Hey, let's play today!	pending	2025-11-13 11:19:09.638722	2025-11-13 11:19:09.638725
6d617cfa-4530-4959-bddf-814e55494686	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 03:00:00	Hey, let's play today!	pending	2025-11-13 11:20:38.968337	2025-11-13 11:20:38.968339
6781e7de-60fb-4bdb-a11e-f376c23bc12b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 04:00:00	Hey, let's play today!	pending	2025-11-13 11:22:48.775065	2025-11-13 11:22:48.775068
b45f2947-4ee2-4c5c-8a87-d11690934fe4	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 05:00:00	Hey, let's play today!	pending	2025-11-13 11:23:59.531863	2025-11-13 11:23:59.531867
e209492f-59ba-4c7f-854f-d05e020af7a4	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 06:00:00	Hey, let's play today!	pending	2025-11-13 11:26:05.227662	2025-11-13 11:26:05.227665
8bf8056e-10f5-4371-a046-9a4c9ad99cf9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 07:00:00	Hey, let's play today!	pending	2025-11-13 11:27:45.9697	2025-11-13 11:27:45.969704
2718d418-e7b8-4053-bfba-aa07075b23a0	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 08:00:00	Hey, let's play today!	pending	2025-11-13 11:33:04.913124	2025-11-13 11:33:04.913127
ac48a200-8ae3-4029-a68f-54bc6be60f78	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 09:00:00	Hey, let's play today!	pending	2025-11-13 11:38:33.577511	2025-11-13 11:38:33.577514
92c0c655-78a0-4229-ad1f-216ed9f94355	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 10:00:00	Hey, let's play today!	pending	2025-11-13 11:40:21.625618	2025-11-13 11:40:21.625621
362fc5bd-ebf5-4337-b33c-d6d1bb09110e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 11:00:00	Hey, let's play today!	pending	2025-11-13 11:43:33.326011	2025-11-13 11:43:33.326015
afa3d174-51bf-4b2b-9281-a02d71c07633	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 12:00:00	Hey, let's play today!	pending	2025-11-13 11:46:02.796935	2025-11-13 11:46:02.796938
95de4a3c-b7f2-4cfb-908b-b6445488e296	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 14:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-13 11:48:02.760214	2025-11-13 11:48:02.760225
df45f20c-a56b-4233-93ab-906cca0623b9	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-13 19:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-13 11:48:02.766652	2025-11-13 11:48:02.766668
f62c1047-8d22-4722-ba9d-2251315a9e72	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 17:00:00	Hey, let's play today!	pending	2025-11-13 12:17:07.843664	2025-11-13 12:17:07.843667
85a6cf39-b492-4027-a867-efcfee8af67f	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 18:00:00	Hey, let's play today!	pending	2025-11-13 12:19:13.048685	2025-11-13 12:19:13.048688
cff3bd17-7c8f-4778-9632-4f456161aeab	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 19:00:00	Hey, let's play today!	pending	2025-11-13 12:21:02.141188	2025-11-13 12:21:02.141191
6de93e75-e61f-4377-9bfb-b2361cfcf95e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 20:00:00	Hey, let's play today!	pending	2025-11-13 12:22:18.325083	2025-11-13 12:22:18.325086
b92b2330-db1e-46b9-8a2d-acdc4fdd44cb	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 21:00:00	Hey, let's play today!	pending	2025-11-13 12:23:08.230516	2025-11-13 12:23:08.230523
196e90f4-f2d0-422f-9b43-cbce1f025262	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 22:00:00	Hey, let's play today!	pending	2025-11-13 12:40:50.004432	2025-11-13 12:40:50.004435
97c1de62-a399-47ee-bdd5-6af40dd9fdc2	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 23:00:00	Hey, let's play today!	pending	2025-11-13 12:58:05.249583	2025-11-13 12:58:05.249587
22d35c04-2514-43b3-adf2-8b7e7ff3dfcf	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 00:00:00	Hey, let's play today!	pending	2025-11-13 13:00:10.885295	2025-11-13 13:00:10.885298
64c5c4ae-c9bd-4236-9cc2-c5d7c9e4f910	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 01:00:00	Hey, let's play today!	pending	2025-11-13 13:02:41.298226	2025-11-13 13:02:41.298229
d7696c1e-5295-498e-8482-73f6ed67468d	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 02:00:00	Hey, let's play today!	pending	2025-11-13 13:05:35.195972	2025-11-13 13:05:35.195975
9bccfe64-7286-401c-83c2-855aa58efbed	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 03:00:00	Hey, let's play today!	pending	2025-11-13 13:11:46.970694	2025-11-13 13:11:46.970698
a4903882-fc08-4384-ae0d-8be4df0ff42a	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 04:00:00	Hey, let's play today!	pending	2025-11-13 13:24:39.317778	2025-11-13 13:24:39.317781
1605df83-8e40-4c42-920d-4b6a7ef05d77	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 05:00:00	Hey, let's play today!	pending	2025-11-13 13:38:09.265419	2025-11-13 13:38:09.265424
2e769bed-5421-413c-ac61-2f167cd7495e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 06:00:00	Hey, let's play today!	pending	2025-11-13 13:38:55.098786	2025-11-13 13:38:55.098789
63d4ed03-be3a-4286-b326-37c57f46cab5	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 07:00:00	Hey, let's play today!	pending	2025-11-13 13:45:39.121042	2025-11-13 13:45:39.121045
b3b70b45-b3eb-4048-a35e-bc94ecebf041	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 08:00:00	Hey, let's play today!	pending	2025-11-13 13:49:19.153594	2025-11-13 13:49:19.153598
9c4fb542-afb2-4216-b57b-34ff2f60132c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 09:00:00	Hey, let's play today!	pending	2025-11-13 13:50:36.733383	2025-11-13 13:50:36.733386
b3006c01-9ca2-4732-991e-e15fcd89286b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 10:00:00	Hey, let's play today!	pending	2025-11-13 14:09:22.024425	2025-11-13 14:09:22.024429
0cafcc97-9928-499f-aa65-3baf8e13f87d	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 11:00:00	Hey, let's play today!	pending	2025-11-13 14:09:47.041701	2025-11-13 14:09:47.041704
6de3c8df-94cd-4417-9788-6c6e6198d47a	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 12:00:00	Hey, let's play today!	pending	2025-11-13 14:10:35.219621	2025-11-13 14:10:35.219624
8b03825e-78c0-4008-9226-4a0a45fe53ae	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 13:00:00	Hey, let's play today!	pending	2025-11-13 14:20:45.581975	2025-11-13 14:20:45.581979
b44eea65-3821-418d-b1dc-8b34c3ecea32	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 14:00:00	Hey, let's play today!	pending	2025-11-13 14:23:51.347824	2025-11-13 14:23:51.347828
1277b458-02fc-4860-9896-ef40d8f6dc37	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 15:00:00	Hey, let's play today!	pending	2025-11-13 14:29:05.086482	2025-11-13 14:29:05.086485
5e316017-02ef-4ddb-8792-3a0222f0f5de	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 16:00:00	Hey, let's play today!	pending	2025-11-13 16:09:50.136474	2025-11-13 16:09:50.136477
03ed1224-f906-4741-8c26-bbe3dc78b818	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 17:00:00	Hey, let's play today!	pending	2025-11-13 16:14:16.64211	2025-11-13 16:14:16.642113
55dbb707-c772-4ac7-b437-7602dca07eb5	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 18:00:00	Hey, let's play today!	pending	2025-11-13 16:17:04.021415	2025-11-13 16:17:04.021419
b79ba39d-14e7-4dcb-aad4-5942562154c7	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 19:00:00	Hey, let's play today!	pending	2025-11-13 23:41:10.558437	2025-11-13 23:41:10.55844
f201eeca-aa4a-45eb-bc7c-aeb32f504a53	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 20:00:00	Hey, let's play today!	pending	2025-11-13 23:43:20.693457	2025-11-13 23:43:20.693461
eab9f19d-12ce-49ad-ac58-e544fc264ba1	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 21:00:00	Hey, let's play today!	pending	2025-11-13 23:45:45.323257	2025-11-13 23:45:45.32326
b2622bb9-c9c0-4938-9692-85a05c861217	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 22:00:00	Hey, let's play today!	pending	2025-11-13 23:48:17.140941	2025-11-13 23:48:17.140944
c199ae1d-56fa-47e4-b900-cae27cdf0f95	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 23:00:00	Hey, let's play today!	pending	2025-11-14 00:26:41.031619	2025-11-14 00:26:41.031623
c182f9f2-f527-457f-9b3b-a013b15feaa2	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 00:00:00	Hey, let's play today!	pending	2025-11-14 00:28:36.254584	2025-11-14 00:28:36.254588
30a79052-bc5b-4683-9bc0-fc2b3d971e4f	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 01:00:00	Hey, let's play today!	pending	2025-11-14 12:00:28.340892	2025-11-14 12:00:28.340896
74137e75-280b-4251-9955-7c9b85479187	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 02:00:00	Hey, let's play today!	pending	2025-11-14 12:09:21.025233	2025-11-14 12:09:21.025236
9c6e918d-f84a-43ad-a5e2-bf2a1861f469	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 15:00:00	\N	pending	2025-11-14 12:37:12.13071	2025-11-14 12:37:12.130714
66ff62a0-c37f-4f7a-a8de-2179b5d37d1d	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-14 16:00:00	\N	pending	2025-11-14 12:37:28.552979	2025-11-14 12:37:28.552982
f3b3d8f8-14a9-4310-b932-ed266c6646d6	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-11-14 23:59:59	\N	pending	2025-11-14 12:37:42.639135	2025-11-14 12:37:42.639138
0d0c4f93-0bac-4361-9cfc-af5905e4049a	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-11-14 10:35:00	\N	pending	2025-11-14 12:38:03.282288	2025-11-14 12:38:03.282291
1ae74324-c5ec-4706-b89a-564cd87d31ed	e78c193d-617f-4e3a-b405-3b71e1c14bfd	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-11-14 10:45:00	\N	pending	2025-11-14 12:39:21.445406	2025-11-14 12:39:21.44541
3bf147cd-0d41-49a6-b598-f76d29204cc4	e78c193d-617f-4e3a-b405-3b71e1c14bfd	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-11-14 10:50:00	\N	pending	2025-11-14 12:40:10.002974	2025-11-14 12:40:10.002977
7450e266-d61e-4973-b618-15814f82df37	e78c193d-617f-4e3a-b405-3b71e1c14bfd	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-11-14 11:17:03	\N	pending	2025-11-14 13:17:21.471504	2025-11-14 13:17:21.471507
f9db3169-d5fe-4507-8d44-ddb392292659	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 03:00:00	Hey, let's play today!	pending	2025-11-14 20:09:10.777958	2025-11-14 20:09:10.777966
2bf58319-2f32-41fb-988e-1c6801667ec1	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	497cd3f6-6ca6-40d5-9641-4ef108bd2a87	2025-11-20 20:00:00	\N	pending	2025-11-14 22:48:21.47129	2025-11-14 22:48:21.471294
1147861c-465f-486d-bcf1-7b0d6730beec	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 04:00:00	Hey, let's play today!	pending	2025-11-15 00:59:41.960914	2025-11-15 00:59:41.960917
8a654d2e-8696-428f-8367-e1b4e8c3b038	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 05:00:00	Hey, let's play today!	pending	2025-11-15 01:00:50.676387	2025-11-15 01:00:50.67639
3686738f-ab4f-491f-8b02-be58f342d1c4	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 10:53:24	Test message from Gemini	pending	2025-11-15 12:53:27.24161	2025-11-15 12:53:27.241613
ad770d15-0432-4c66-bc11-751550647a65	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 11:05:06	Test message from Gemini	pending	2025-11-15 13:05:09.22708	2025-11-15 13:05:09.227083
74b67635-9c15-40e3-aa66-15cd18011a96	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 11:17:00	Test message from Gemini after fix - new token	pending	2025-11-15 13:17:02.613741	2025-11-15 13:17:02.613744
c42c3c23-9b73-412e-a648-3985c9b196a9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 11:18:13	Test message from Gemini after fix - new token and debug prints	pending	2025-11-15 13:18:16.562135	2025-11-15 13:18:16.562138
ca871696-f1f4-40b1-a665-fdda2066d1f3	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 11:22:14	Test message from Gemini after fix - new token and debug prints - third try	pending	2025-11-15 13:22:17.162887	2025-11-15 13:22:17.162891
7c023341-c212-43ee-9223-022f34795254	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-15 11:25:21	Test message from Gemini after HMR fix - final try	pending	2025-11-15 13:25:23.68626	2025-11-15 13:25:23.686264
eb61ac64-7c6c-4b7b-9a57-40d1e243697f	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 10:00:00	Test game request from Invoke-WebRequest	pending	2025-11-15 14:42:51.273347	2025-11-15 14:42:51.27335
9b589506-ffee-465e-87fd-41e4348e4cab	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 20:00:00	Test message	pending	2025-11-15 16:41:28.926555	2025-11-15 16:41:28.926559
0047ac96-0588-4fe7-90a9-6b35de7ad5cd	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-20 20:00:00	Test message	pending	2025-11-15 17:07:02.268308	2025-11-15 17:07:02.268314
93562cb2-24ed-4b23-8250-6f8fbe668e9c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 20:00:00	Test message	pending	2025-11-15 17:07:36.87554	2025-11-15 17:07:36.875543
54ae52af-b97d-432b-bdca-962f9f6d4946	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-22 20:00:00	Test message	pending	2025-11-15 17:08:06.83717	2025-11-15 17:08:06.837173
8f6435cb-276a-45fc-8bdb-4a3a9ebca85e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-23 20:00:00	Test message	pending	2025-11-15 17:08:42.417327	2025-11-15 17:08:42.417331
865443ba-66a1-4e60-832b-a07adebb6021	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 06:00:00	Hey, let's play today!	pending	2025-11-15 19:41:46.851137	2025-11-15 19:41:46.851141
f9f2b058-74e4-4a17-aede-be07e6bef715	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 07:00:00	Hey, let's play today!	pending	2025-11-15 19:46:48.134951	2025-11-15 19:46:48.134954
a818ba73-de3b-44c7-a7d5-90c3d741a285	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 08:00:00	Hey, let's play today!	pending	2025-11-15 19:47:52.430568	2025-11-15 19:47:52.430571
f2de0237-bb0c-4d81-9d42-f018cff61857	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 09:00:00	Hey, let's play today!	pending	2025-11-15 20:03:17.005628	2025-11-15 20:03:17.005633
c1d1614b-8d5d-4fdd-b22f-ce09467b1252	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 11:00:00	Hey, let's play today!	pending	2025-11-15 20:32:19.356032	2025-11-15 20:32:19.356035
fba72c1b-e3e6-4548-a27e-c7454ce4b53a	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 12:00:00	Hey, let's play today!	pending	2025-11-16 00:35:41.902202	2025-11-16 00:35:41.902207
90753945-70a5-4098-b63d-ee4bdd230c03	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 13:00:00	Hey, let's play today!	pending	2025-11-16 00:46:19.221229	2025-11-16 00:46:19.221232
245db162-3dd2-46e8-92df-b219f3e2dc24	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 09:00:00	test	pending	2025-11-16 22:59:59.230667	2025-11-16 22:59:59.230671
b794d0e7-c2b9-4048-a30c-71899a103a99	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 14:00:00	Hey, let's play today!	pending	2025-11-16 23:09:31.438753	2025-11-16 23:09:31.438756
1342f102-f77c-4ecb-9462-dd2e5f904828	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 15:00:00	Hey, let's play today!	pending	2025-11-17 09:02:31.253922	2025-11-17 09:02:31.253926
bf20a7f6-19c0-4055-8e39-4eee5cc26a32	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-11-18 03:00:00	Hey! Would you be up for a game of Minecraft?	accepted	2025-11-17 10:19:55.213851	2025-11-17 10:25:18.412591
8ea5e6f2-c578-4491-b322-6af11c01a8f1	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 19:00:00	Hey, let's play today!	pending	2025-11-17 11:07:41.793536	2025-11-17 11:07:41.793539
bd75bb91-0e46-467c-9b03-a2548209b290	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 18:00:00	Hey, let's play today!	Accepted	2025-11-17 11:06:41.705361	2025-11-17 10:48:47.097202
4753e2cf-f78e-4373-b6de-5496a0547f23	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 17:00:00	Hey, let's play today!	Accepted	2025-11-17 10:49:28.92591	2025-11-17 10:48:47.097202
f0536665-b650-4b31-9e65-0b7d02de6893	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 16:00:00	Hey, let's play today!	Accepted	2025-11-17 10:20:37.346576	2025-11-17 11:31:19.083684
0c2d4f45-19f9-4604-b713-68ca14e0f630	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 20:00:00	Test message	accepted	2025-11-15 16:44:10.251507	2025-11-17 11:55:35.063638
22997769-f86b-4b86-ac57-e6583258da33	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-18 20:00:00	Test message	accepted	2025-11-15 17:03:55.587863	2025-11-17 11:55:35.063638
06fff4be-0e49-4208-8ab4-f838a9fdc936	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-19 20:00:00	Test message	accepted	2025-11-15 17:06:12.487868	2025-11-17 11:55:35.063638
a0e38357-4df4-4a4c-83da-6b0e6cba8aac	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 21:00:00	Hey, let's play today!	pending	2025-11-17 12:06:08.691399	2025-11-17 12:06:08.691403
9196325f-965d-44b2-b35a-f31bbf9a6748	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 22:00:00	Hey, let's play today!	pending	2025-11-17 12:09:58.465281	2025-11-17 12:09:58.465285
e265dae3-1b1f-42fb-bb63-e952c62c94de	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-16 23:00:00	Hey, let's play today!	pending	2025-11-17 12:12:33.675126	2025-11-17 12:12:33.67513
6f4091e4-f707-438c-a203-d16573e8a504	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 00:00:00	Hey, let's play today!	pending	2025-11-17 12:13:01.899506	2025-11-17 12:13:01.899509
11551f5b-0928-475e-afb1-862dddf1d2d1	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	f7d77de5-d20e-4196-aa87-c4aa3f831d23	2025-11-19 19:00:00	Hey! Would you be up for a game of Stardew Valley?	pending	2025-11-18 08:11:56.524751	2025-11-18 08:11:56.524757
15cc7002-b0c3-4de6-ac72-466770d223de	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 08:00:00	Hey! Would you be up for a game of Chess?	accepted	2025-11-18 07:47:00.706989	2025-11-18 10:47:22.687567
0906c632-96f8-4500-b5eb-cd67c1fd1ada	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	f7d77de5-d20e-4196-aa87-c4aa3f831d23	2025-11-20 17:00:00	Hey! Would you be up for a game of Stardew Valley?	accepted	2025-11-18 09:02:09.79655	2025-11-18 10:47:22.687567
db32bb43-d427-4804-a7f2-e85d620e554f	35bdfe00-4545-46f6-ad25-df895f7d4ed9	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	f7d77de5-d20e-4196-aa87-c4aa3f831d23	2025-11-19 18:00:00	Hey! Would you be up for a game of Stardew Valley?	pending	2025-11-18 11:07:31.96179	2025-11-18 11:07:31.961794
ec75c37d-bc42-4693-b27e-daddaeebcdc8	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	f7d77de5-d20e-4196-aa87-c4aa3f831d23	2025-11-20 04:00:00	Hey! Would you be up for a game of Stardew Valley?	accepted	2025-11-18 09:02:09.839336	2025-11-18 12:21:22.931158
3af88191-f76a-4841-84d5-4efeea4c3fe9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 02:00:00	Hey, let's play today!	pending	2025-11-18 12:41:54.758996	2025-11-18 12:41:54.758999
7f0815c5-44dd-4bfb-a965-50d1fa5a8073	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 03:00:00	Hey, let's play today!	pending	2025-11-18 12:42:28.114309	2025-11-18 12:42:28.114312
cdbf5aa3-ff1d-4b14-9fc3-f4c14561f25c	35bdfe00-4545-46f6-ad25-df895f7d4ed9	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-19 13:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-18 12:52:04.794048	2025-11-18 12:52:04.794063
2414c669-3824-44e7-b4c0-580530a754b2	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 04:00:00	Hey, let's play today!	pending	2025-11-20 09:16:38.619624	2025-11-20 09:16:38.619627
9e6b55e4-4625-42fa-9be6-2b9af6dfc325	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 05:00:00	Hey, let's play today!	pending	2025-11-20 10:18:46.75449	2025-11-20 10:18:46.754493
0ccd9a35-56fb-4e96-854e-873569053901	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-20 23:00:00	Test message for verification (second attempt)	pending	2025-11-20 10:23:04.342952	2025-11-20 10:23:04.342955
15069e90-8343-4248-a310-ac57d17e4fcc	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 00:00:00	Test message for verification (third attempt)	pending	2025-11-20 10:23:51.095781	2025-11-20 10:23:51.095784
cb22563d-998b-4ebc-b0e8-dbccabe5a48e	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 02:00:00	Test message after commenting out 401 redirect	pending	2025-11-20 10:44:14.928125	2025-11-20 10:44:14.928128
6f8b282b-76a7-410c-8785-c6a517d0a408	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 03:00:00	Test for notification event	pending	2025-11-20 10:51:45.036553	2025-11-20 10:51:45.036555
24190ba5-9202-4840-9003-d51d5d0e5ad9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 04:00:00	Test after increasing pingTimeout	pending	2025-11-20 10:56:59.772064	2025-11-20 10:56:59.772067
205a308a-8493-4939-809f-2dcf1f501667	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-19 08:00:00	Hey! Would you be up for a game of Chess?	rejected	2025-11-18 07:47:00.703086	2025-11-20 09:14:35.285298
9cd8e7b8-592c-468b-a03d-a4e6f126c947	35bdfe00-4545-46f6-ad25-df895f7d4ed9	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-23 15:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-20 12:17:26.50256	2025-11-20 12:17:26.502563
42354466-970a-41cd-af70-2dc29c84bffc	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 07:00:00	Test after moving SocketProvider	pending	2025-11-20 12:50:08.259235	2025-11-20 12:50:08.25924
7f34d1d3-3177-4daa-a315-8b48a738e3ee	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 13:00:00	Hey, let's play today!	pending	2025-11-20 15:31:03.50245	2025-11-20 15:31:03.502454
f7a77d55-5c79-4134-827d-83b2b210c21c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-17 15:00:00	Hey, let's play today!	pending	2025-11-20 17:44:42.829497	2025-11-20 17:44:42.8295
4dcdca2e-8312-4996-bcb1-3743a1c5d529	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-18 00:00:00	Test game request	pending	2025-11-21 10:07:21.048098	2025-11-21 10:07:21.0481
f9d41e64-ecf2-4216-b4e5-4761d77a4a75	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 10:00:00	Test game request	pending	2025-11-22 00:26:03.170303	2025-11-22 00:26:03.170309
4e8e1ce0-77a4-40c6-b91a-9187736d7838	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-21 13:00:00	Test game request	pending	2025-11-22 00:32:22.736337	2025-11-22 00:32:22.736341
77bfa5d8-12b3-4385-938c-d14c55df96b2	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-26 00:00:00	Test game request	pending	2025-11-22 00:43:58.331045	2025-11-22 00:43:58.331047
1d2c7032-cf4c-4451-b16b-1ad1f1071807	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-29 00:00:00	Test game request	pending	2025-11-22 00:46:41.631074	2025-11-22 00:46:41.631078
617fd7c8-0bff-4eae-abe6-7f0d1d6ae264	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-18 01:00:00	Hey, let's play today!	pending	2025-11-26 10:16:06.629106	2025-11-26 10:16:06.62911
9a776b35-9d2a-43c3-8af5-20865d8d3a30	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-18 02:00:00	Hey, let's play today!	pending	2025-11-26 10:18:59.454201	2025-11-26 10:18:59.454204
47da74be-e31e-41b3-9c07-6723bc868e5b	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-12-03 10:00:00	Hey! Would you be up for a game of Chess?	rejected	2025-11-26 12:12:06.423361	2025-11-26 11:51:07.887238
4540806c-f7ac-4ba4-8026-67ebbea61104	d30c48fa-94ab-4c6e-a72c-7b19781094db	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-12-02 13:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-26 12:16:06.570316	2025-11-26 12:16:06.570319
b6e59e65-b658-42de-88c2-980607fb93ed	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-12-03 12:00:00	Hey! Would you be up for a game of Minecraft?	rejected	2025-11-26 12:15:30.065871	2025-11-26 12:33:05.15734
4479478c-39ae-45d0-bd14-67f993d7c88e	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	7ed96bfa-fd02-47d2-beca-39e73e689b4f	2025-12-03 11:00:00	Hey! Would you be up for a game of Minecraft?	cancelled	2025-11-26 12:15:29.767166	2025-11-26 12:46:08.077295
c48bbf30-d404-4a32-a418-2f16e11aa152	ad32159d-b60a-415f-95d0-5a84548d626c	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-28 10:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-26 12:47:47.019103	2025-11-26 12:47:47.019106
bb7fd2e8-d833-4446-8132-8e27b94243ac	ad32159d-b60a-415f-95d0-5a84548d626c	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-28 11:00:00	Hey! Would you be up for a game of Chess?	pending	2025-11-26 12:47:47.288919	2025-11-26 12:47:47.288923
05580c1f-06ed-4935-9392-4c0e5e7f5858	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-26 13:00:00	Hey! Would you be up for a game of Chess?	accepted	2025-11-26 12:47:59.54621	2025-11-26 12:46:08.077295
f881b5dc-1916-42c3-a430-a8966714caf3	d30c48fa-94ab-4c6e-a72c-7b19781094db	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-11-26 13:00:00	Hey! Would you be up for a game of Chess?	rejected	2025-11-26 12:16:06.26274	2025-11-26 12:46:08.077295
32b4b462-c981-4900-8148-1280a4bf885a	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-12-03 11:00:00	Hey! Would you be up for a game of Chess?	cancelled	2025-11-26 12:47:59.281926	2025-11-26 12:46:08.077295
6a2a6c44-0686-43b2-ad1c-02d5a8553505	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	d356375b-650f-4b83-8c22-ebc8310a74ef	2025-12-03 12:00:00	Hey! Would you be up for a game of Chess?	cancelled	2025-11-26 12:47:59.546942	2025-11-26 12:46:08.077295
\.


--
-- Data for Name: ProtectionStatus; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."ProtectionStatus" (id, protection_enabled, installed_at, last_verified, version) FROM stdin;
1	t	2025-12-02 18:38:41.565016	2025-12-02 18:38:41.565016	3.0
\.


--
-- Data for Name: ScheduledSession; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."ScheduledSession" (id, game_id, organizer_user_id, second_player_id, scheduled_date, start_time, end_time, timezone, status, session_id, session_type, max_participants, description, meeting_link, reminder_sent, game_site_url, created_at) FROM stdin;
3012640a-5fc8-4942-ada0-370c4c58c53d	d356375b-650f-4b83-8c22-ebc8310a74ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-16	18:00:00	19:00:00	IDT	completed	bd75bb91-0e46-467c-9b03-a2548209b290	private	2	\N	\N	f	\N	2025-11-17 11:34:16.921761
31bb67de-e9c2-4efc-9b9b-8e8fb395cf33	d356375b-650f-4b83-8c22-ebc8310a74ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-16	17:00:00	18:00:00	IDT	completed	4753e2cf-f78e-4373-b6de-5496a0547f23	private	2	\N	\N	f	\N	2025-11-17 11:34:30.113122
c504f57d-93eb-4450-8f9d-71610cff8e5a	d356375b-650f-4b83-8c22-ebc8310a74ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-16	16:00:00	17:00:00	IDT	completed	f0536665-b650-4b31-9e65-0b7d02de6893	private	2	\N	\N	f	\N	2025-11-17 11:42:43.842619
2d427749-6978-4a6a-bbf2-f2ac31e5ea81	d356375b-650f-4b83-8c22-ebc8310a74ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-17	20:00:00	21:00:00	IDT	completed	0c2d4f45-19f9-4604-b713-68ca14e0f630	private	2	\N	discord not found in guild.\ndiscord and avi.temp, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-17 12:00:17.194189
5a49950c-e571-4be6-828b-df7b2897581e	7ed96bfa-fd02-47d2-beca-39e73e689b4f	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	2025-11-18	03:00:00	04:00:00	IDT	completed	bf20a7f6-19c0-4055-8e39-4eee5cc26a32	private	2	\N	b not found in guild.\ntovplay and b, please go to https://discord.com and search for each other	f	https://www.minecraft.net/	2025-11-17 10:27:08.839038
26173286-543f-4254-978b-9064b5fd82ee	f7d77de5-d20e-4196-aa87-c4aa3f831d23	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	2025-11-20	04:00:00	05:00:00	IDT	completed	ec75c37d-bc42-4693-b27e-daddaeebcdc8	private	2	Have fun playing Stardew Valley! \nIn order to chat go to https://discord.com/channels/1432632270853898240/1440288150000767133, in order to play the game go to https://www.stardewvalley.net/.\nEnjoy!	https://discord.com/channels/1432632270853898240/1440288150000767133	f	https://www.stardewvalley.net/	2025-11-18 12:30:54.10947
44bbd31c-14c9-41bc-9850-a3a7c4f96751	d356375b-650f-4b83-8c22-ebc8310a74ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-18	20:00:00	21:00:00	IDT	completed	22997769-f86b-4b86-ac57-e6583258da33	private	2	\N	discord not found in guild.\ndiscord and avi.temp, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-17 12:00:31.404941
808f9ba5-ec0a-4e67-99b1-cc9697f583cc	f7d77de5-d20e-4196-aa87-c4aa3f831d23	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	2025-11-20	17:00:00	18:00:00	IDT	completed	0906c632-96f8-4500-b5eb-cd67c1fd1ada	private	2	\N	https://discord.com/channels/1432632270853898240/1440266915342844017	f	https://www.stardewvalley.net/	2025-11-18 11:06:31.187651
762aeb2a-a2ea-4f59-8537-3adc53ec7b08	d356375b-650f-4b83-8c22-ebc8310a74ef	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	35bdfe00-4545-46f6-ad25-df895f7d4ed9	2025-11-19	09:00:00	10:00:00	IDT	completed	5d14bf99-6ea5-4b4a-ae86-704845b5101e	private	2	\N	\N	f	\N	2025-11-18 13:00:15.976613
dbebca34-b2e7-4990-9cd3-14e2c79f06d7	d356375b-650f-4b83-8c22-ebc8310a74ef	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-19	20:00:00	21:00:00	IDT	completed	06fff4be-0e49-4208-8ab4-f838a9fdc936	private	2	\N	discord not found in guild.\ndiscord and avi.temp, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-17 12:00:59.923328
5cbaabd1-9566-45fa-bbd5-bb01b69acf63	d356375b-650f-4b83-8c22-ebc8310a74ef	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	2025-11-21	08:00:00	09:00:00	IDT	completed	15cc7002-b0c3-4de6-ac72-466770d223de	private	2	\N	b not found in guild.\nb and tovplay, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-18 10:59:56.34053
905fde8b-8506-421f-9e38-f9b347e374b3	d356375b-650f-4b83-8c22-ebc8310a74ef	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	e78c193d-617f-4e3a-b405-3b71e1c14bfd	2025-11-24	02:00:00	03:00:00	IDT	completed	32e9cdc2-eb49-4a64-a601-d71e96a2b8ff	private	2	\N	\N	f	\N	2025-11-18 12:48:14.505311
bfaafc65-80ad-42b3-adf0-00a303bb87ac	7ed96bfa-fd02-47d2-beca-39e73e689b4f	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	2025-12-03	11:00:00	12:00:00	IDT	cancelled	4479478c-39ae-45d0-bd14-67f993d7c88e	private	2	\N	Xddd not found in guild.\nSuperRoman19 not found in guild.\nXddd and SuperRoman19, please go to https://discord.com and search for each other	f	https://www.minecraft.net/	2025-11-26 12:33:49.044185
b4db2de8-c1f2-4d67-87bb-2ded90de6d22	d356375b-650f-4b83-8c22-ebc8310a74ef	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	2025-12-03	12:00:00	13:00:00	IDT	cancelled	6a2a6c44-0686-43b2-ad1c-02d5a8553505	private	2	\N	Xddd not found in guild.\nSuperRoman19 not found in guild.\nXddd and SuperRoman19, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-26 13:35:47.573162
c9d9cbd2-c3a9-4042-886a-ae13ef08e64b	d356375b-650f-4b83-8c22-ebc8310a74ef	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	2025-12-03	11:00:00	12:00:00	IDT	cancelled	32b4b462-c981-4900-8148-1280a4bf885a	private	2	\N	Xddd not found in guild.\nSuperRoman19 not found in guild.\nXddd and SuperRoman19, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-26 12:52:28.153725
416c6a59-869c-43e9-9c70-06ca87af4f99	d356375b-650f-4b83-8c22-ebc8310a74ef	ad32159d-b60a-415f-95d0-5a84548d626c	d30c48fa-94ab-4c6e-a72c-7b19781094db	2025-11-26	13:00:00	14:00:00	IDT	completed	05580c1f-06ed-4935-9392-4c0e5e7f5858	private	2	\N	Xddd not found in guild.\nSuperRoman19 not found in guild.\nXddd and SuperRoman19, please go to https://discord.com and search for each other	f	https://www.chess.com/	2025-11-26 12:48:51.8967
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."User" (id, email, discord_id, username, discord_username, hashed_password, verified, in_community, created_at, updated_at, avatar_url, role) FROM stdin;
389bad2c-cbbf-4539-9f96-17afca8ce233	kerenwedel@gmail.com	1409483469087707208	kerenwedel	mizuki_kcw	\N	t	t	2025-11-11 09:13:45.274377	2025-11-11 09:13:45.274386	https://cdn.discordapp.com/avatars1409483469087707208/None.png	player
20d4a1ac-f4b1-4332-a6bb-7a0480010a71	claudetest1763551663@tovplay.test	\N	claudetest1763551663	claudetest1763551663	$2b$12$86BLfQeA4JCSstPCMGI6pej8NlQJZR6C87GKiborpUA239suNyaY2	f	f	2025-11-19 11:27:44.2368	2025-11-19 11:27:44.23681	\N	player
ef52ee5d-4e70-42f4-9b45-df4ec56b9682	lilachherzog.work@gmail.com	\N	lil	lil	$2b$12$DoLXyR/T3hFiBn5bq2krqujqnuH2CHoWIjqJcEwbQER9k2xjAG3C6	t	f	2025-09-15 11:44:14.376881	2025-09-15 11:44:14.376889	\N	player
6a7cf057-9a07-4e15-9ce3-b2644d6f4101	ptest@tovplay.test	\N	ptest	ptest	$2b$12$QCV5GH9cGloAzpM98Ftfb.ehYrC4h2LBS/yUVDeJGfYOoSOJR4fS6	f	f	2025-11-19 12:29:22.094274	2025-11-19 12:29:22.09428	\N	player
dd2d069c-540a-443d-9851-5fb207abb011	finaltest1763555745@tovplay.test	\N	finaltest1763555745	finaltest1763555745	$2b$12$/FvfnV//AQ/LriBZq0cf9e7.iIXt1kbdO9VdtW8Szf1CLmxkyrJC2	f	f	2025-11-19 12:35:46.508505	2025-11-19 12:35:46.508518	\N	player
00000000-0000-0000-0000-00000000abcd	test.reset@tovtech.org	\N	resetuser	resetuser#0001	$2b$12$uXZyENpbxGqRjkpR7zNG7uGoBWVjcg5rfjTwf95EfK6vYiZUKPdcu	t	t	2025-11-13 09:06:06.889632	2025-11-13 09:06:06.889632	\N	\N
e78c193d-617f-4e3a-b405-3b71e1c14bfd	avi12.test@gmail.com	1435207957418868736	Avi temp	avi.temp	\N	t	t	2025-11-05 08:56:16.160202	2025-11-05 08:56:16.160205	https://cdn.discordapp.com/avatars1435207957418868736/None.png	player
04ffeddb-f14c-4a7a-930b-b06175b3dc4d	b@b.com	\N	b	b	$2b$12$XPaoTZuH/iFsGUy5yx9loOiL9ueW4vdKVqmaQ7XAwfwvU3I68eERy	t	f	2025-09-01 14:21:28.495802	2025-09-01 14:21:28.495813	\N	"player"
ff07e8f3-a942-4c8e-abdf-11d036aad886	uv.zeyger@gmail.com	\N	heir	heir#0000	$2b$12$dDF3jWpRmK0Kpo6KM/GqC.W9wdQphFJZSX5HAIYnKwCC05oacVRSe	t	f	2025-11-17 07:41:01.870036	2025-11-17 07:41:01.870036	\N	player
c0367e50-b52c-4e8e-b1ee-aac24a26aa99	lilach.m.h@gmail.com	501302354956779520	lilach0492	lilach0492	\N	t	t	2025-11-18 09:01:14.831799	2025-11-18 09:01:14.831804	https://cdn.discordapp.com/avatars501302354956779520/c130b7a0d32b8eb270c308e201d1ff70.png	player
dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	test@gmail.com	\N	CozyGamer	discord	$2b$12$tV8oiVFgXawxzyPMJ/dOPsR18NJMEJByM.iHxfP62nfEIp8xwfG	t	\N	2025-09-11 14:11:36.93676	2025-09-11 14:11:36.936768	\N	"player"
b7973fc9-8cdf-4ae0-8a33-f7ab180df983	e@e	\N	e	e	$2b$12$mvMXrWeoCfWCfWkDNaAub6jdjZ21Y0KEqulykZgCBxDrhatsnyK	t	f	2025-09-01 14:22:35.647504	2025-09-01 14:22:35.647515	\N	"player"
65623720-4f3b-472f-9ee1-505ad5c02461	test@test.com	\N	avi	avi12	$2b$12$OQ.dBBnoTdcOxczEo7107uyKElYPQpyu5CY4tGr0a4dgLj85GnDKa	t	f	2025-09-23 15:20:06.284678	2025-09-23 15:20:06.284687	\N	Admin
1c001b52-2075-4df3-b3e4-0ecae3949e72	puppeteertest1763558955@tovplay.test	\N	puppeteertest1763558955	puppeteertest1763558955	$2b$12$M6gqMfqdggXBLo84Pia2.VtuLtsuYAJh.n4hoKutbt08cwWAEy4u	f	f	2025-11-19 13:29:15.774231	2025-11-19 13:29:15.774238	\N	player
a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	c@c	\N	c	lilach	$2b$12$ba4hks4c.jMLwxtcUWCufnw4BH5o97.uHouFeVykcZpBoW3PfDO	t	f	2025-09-01 14:21:49.683013	2025-09-01 14:21:49.683022	\N	"player"
9444af7b-fbee-48b3-a920-2aa73ab1c651	workingtest@test.com	\N	workingtest	workingtest	$2b$12$rbV2sYt0rjJ9WLQicH2BeemipJOMVlB4Vr./MuwR.55/sRjOzXY.	f	f	2025-11-19 11:03:35.729166	2025-11-19 11:03:35.729173	\N	player
ad32159d-b60a-415f-95d0-5a84548d626c	xddd.xddd@test.com	\N	Xddd	Xddd	$2b$12$QArFT0qw88wv0gO7Bg9U5ube022K6GmpiykOcq8za/0ZEQH1iIVwS	t	\N	2025-11-26 12:09:21.139835	2025-11-26 12:09:21.139839	\N	player
d30c48fa-94ab-4c6e-a72c-7b19781094db	roman.fes@test.com	\N	Roman	SuperRoman19	$2b$12$.qYh/ykRA.xxTP7YnmXkGe.EMJnJBMRjm1YYOdzghWC.17QglkzAS	t	t	2025-11-26 10:36:56.015879	2025-11-26 10:36:56.015883	\N	player
4c628486-6ccf-4554-862b-3acb68ff4bcf	sharonshaaul@gmail.com	\N	bob	bob	$2b$12$1N.pQSWdFu3XWbzDpSoUZ.03TiRcA4P9MP.T7//jesoIudoOugXvy	f	f	2025-11-26 12:40:14.74935	2025-11-26 12:40:14.749355	\N	player
35bdfe00-4545-46f6-ad25-df895f7d4ed9	d@d	\N	d	d	$2b$12$c102IBbvyfFpLf1KOffONGH1dZfH9r74ukfUCjsWzpjNf96m4Rm	t	f	2025-09-01 14:22:10.43939	2025-09-01 14:22:10.439399	\N	"player"
9e717c10-6db1-46dd-bc00-9295665051a5	verifytest@tovplay.test	\N	verifytest	verifytest#0000	$2b$12$JL4lvwYZ9rIvh7V/ctGfLu/s5vX.7/gUoLEBB8JuNDKaxA7Im3Mz.	t	f	2025-12-02 14:20:22.050835	2025-12-02 14:20:22.050842	\N	player
116685e0-0f6b-4d57-936a-708e737a7d4e	bugtest@example.com	\N	BugTester	BugTest#1234	$2b$12$5pEQdyJ/6Pvd2eDCk8exb.1.H9hGWPTjJcCDP66BGfFClHjAUiDZW	f	f	2025-12-08 09:25:04.706779	2025-12-08 09:25:04.706785	\N	player
db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	tovplay@tovtech.org	1432630222934773835	TovPlay	tovplay	$2b$12$XPaoTZuH/iFsGUy5yx9loOiL9ueW4vdKVqmaQ7XAwfwvU3I68eERy	t	t	2025-11-03 10:32:24.805652	2025-11-03 10:32:24.805663	https://cdn.discordapp.com/avatars1432630222934773835/None.png	player
fa649872-83b8-4f32-80be-7441feecd331	torhadas@gmail.com	1003174240842948659	torhadas	torhadas	\N	t	t	2025-12-16 09:31:06.97887	2025-12-16 09:31:06.97887	https://cdn.discordapp.com/avatars1003174240842948659/None.png	player
\.


--
-- Data for Name: UserAvailability; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."UserAvailability" (id, user_id, day_of_week, start_time, end_time, is_recurring, updated_at) FROM stdin;
9c610423-0165-47ff-9510-0defd09d57ef	65623720-4f3b-472f-9ee1-505ad5c02461	Thursday	11:00:00	13:00:00	f	2025-11-10 11:01:03.203952
315fa926-c496-46ff-8b5c-bc7c889d757d	65623720-4f3b-472f-9ee1-505ad5c02461	Friday	03:00:00	05:00:00	f	2025-11-10 11:01:03.20948
307d393a-11c8-4029-96d0-c6c411877d6b	65623720-4f3b-472f-9ee1-505ad5c02461	Friday	12:00:00	15:00:00	f	2025-11-10 11:01:03.214968
36ef6453-b997-4549-af33-e033a4e19ecf	65623720-4f3b-472f-9ee1-505ad5c02461	Saturday	14:00:00	16:00:00	f	2025-11-10 11:01:03.220508
6400b714-14be-44a9-a060-4309f321f0be	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Tuesday	05:00:00	06:00:00	f	2025-11-11 15:43:54.716153
a92724b8-5ac2-4cd6-add8-1fd96aade9de	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Wednesday	04:00:00	05:00:00	f	2025-11-11 15:43:55.322362
d8f8c29c-667a-45f1-a933-a92ef7a35348	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Wednesday	13:00:00	14:00:00	f	2025-11-11 15:43:55.61784
768008d6-f430-4738-aa5b-ad701c3c2b28	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Thursday	04:00:00	05:00:00	f	2025-11-11 15:43:55.919628
5289a10e-9a0b-4e70-bda1-c6c2cb31ac78	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Thursday	13:00:00	14:00:00	f	2025-11-11 15:43:56.23843
f750af30-4f46-45c3-874b-97b2015a65a1	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Friday	13:00:00	14:00:00	f	2025-11-11 15:43:56.804676
c5894f4d-50bc-45be-b232-4eed0911915c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Saturday	04:00:00	06:00:00	f	2025-11-11 15:43:57.109223
8d03124e-8074-4e32-b60d-97e60bf1f0d7	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Sunday	05:00:00	14:00:00	f	2025-11-11 15:43:57.703724
5ae8ad09-627b-4b91-b861-67798b8ac277	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Friday	06:00:00	09:00:00	f	2025-10-29 13:30:17.573517
2a61c8ff-8f8e-49f7-8213-f6e594640cea	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Saturday	16:00:00	17:00:00	f	2025-10-29 13:30:18.18988
a20bda46-b419-4660-a86c-be7504dd74da	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Saturday	20:00:00	22:00:00	f	2025-10-29 13:30:18.491958
9f2de2c0-ec19-4c4b-9ff1-6dd53ad352fd	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Thursday	13:00:00	15:00:00	f	2025-10-29 13:30:18.864376
f8fa1e16-6471-4d51-b7a2-2e5dd02df59e	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Wednesday	06:00:00	10:00:00	f	2025-10-29 13:30:19.183203
1272b792-e17f-4f14-8037-129845acece6	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Wednesday	13:00:00	14:00:00	f	2025-10-29 13:30:19.486427
83a98527-ec6e-4f08-b41f-fe75bd661658	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Monday	04:00:00	09:00:00	f	2025-10-29 13:30:20.436618
d284194f-9d26-4096-bc6d-28c139d46964	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Monday	18:00:00	22:00:00	f	2025-10-29 13:30:20.739206
87cc1f28-120f-47a5-853d-a084b17679cd	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Friday	13:00:00	14:00:00	f	2025-10-29 13:30:22.000384
8791e4c9-6bd5-4a80-8d60-1e108d58f58e	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Friday	16:00:00	18:00:00	f	2025-10-29 13:30:22.302752
f81bb5f1-458c-49d1-9713-a46577a1a934	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Sunday	08:00:00	16:00:00	f	2025-10-29 13:30:23.571509
9b164856-f286-4f6a-85eb-abfa424a438c	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Wednesday	00:00:00	17:00:00	f	2025-10-22 11:31:07.134179
036eda18-f8d6-4eff-bfe9-7dc11aee7f4d	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Monday	00:00:00	16:00:00	f	2025-10-22 11:31:07.134179
9aa09f0a-79e9-400f-9b25-3524caebe6bf	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	06:00:00	07:00:00	f	2025-11-03 10:31:00.743828
abbc3efa-6a70-4cc9-b726-b8e41f06b5bc	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Tuesday	03:00:00	06:00:00	f	2025-11-03 10:31:01.100519
3d1df632-bcee-4a60-8a04-2ede62e21a63	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Thursday	00:00:00	21:00:00	f	2025-10-22 11:31:07.134179
d1b3fa13-764c-4254-90a3-d8b89d596c07	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Friday	00:00:00	16:00:00	f	2025-10-22 11:31:07.134179
975f2c5e-3e28-43f3-9aad-a64ba1ce5493	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Saturday	14:00:00	16:00:00	f	2025-10-22 11:31:07.134179
ffa705fd-316b-4419-ad5a-40c195da00ab	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Saturday	18:00:00	19:00:00	f	2025-10-22 11:31:07.134179
fd8ad576-b227-4fab-8d6e-281c9430b531	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Wednesday	00:00:00	17:00:00	f	2025-10-22 11:31:07.134179
5f978c40-3c5d-41fa-a6bd-a9f008d4e91b	35bdfe00-4545-46f6-ad25-df895f7d4ed9	Wednesday	09:00:00	23:00:00	f	2025-10-22 11:31:07.134179
2c5bdea7-e1cf-4a18-a8d7-432087231342	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	11:00:00	12:00:00	f	2025-11-03 10:31:01.473353
302d04a9-8eea-41cc-86ac-89caf8750534	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Tuesday	11:00:00	13:00:00	f	2025-11-03 10:31:01.88721
04e5326a-c7e7-456d-8e33-e148020fa0ce	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	15:00:00	16:00:00	f	2025-11-03 10:31:02.247534
b0308be7-74b1-480e-8616-2ba9124249c9	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Tuesday	18:00:00	20:00:00	f	2025-11-03 10:31:02.582033
84599a5f-8683-46ce-b14b-0992594931d7	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Friday	03:00:00	04:00:00	f	2025-11-03 10:31:02.91503
94872e44-1391-4333-bcbf-61c22e0c7320	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	03:00:00	04:00:00	f	2025-11-03 10:31:03.245901
f7a60eeb-24b0-4b9b-836d-da7ce88e2a29	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Friday	08:00:00	09:00:00	f	2025-11-03 10:31:03.60361
27b0def6-b7a0-4b96-9ab3-64c52a9f7ad9	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	11:00:00	15:00:00	f	2025-11-03 10:31:06.504182
89c1ed13-3ce8-4d14-b7e0-8f4b105445d8	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Thursday	03:00:00	04:00:00	f	2025-11-03 10:31:07.592287
b339c016-22a2-440d-8e9e-de606856cb05	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	06:00:00	07:00:00	f	2025-11-03 10:31:09.811419
3bb23918-4a08-4787-9e21-944811db1ea8	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	19:00:00	22:00:00	f	2025-11-03 10:31:11.613752
46c321c3-0a03-422c-be66-3a9320a8b830	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	18:00:00	19:00:00	f	2025-11-03 10:31:13.431657
3a40538c-ab97-4489-bc33-3ba0ced028a7	65623720-4f3b-472f-9ee1-505ad5c02461	Monday	01:00:00	03:00:00	f	2025-11-10 11:01:03.176441
78e8893e-bc1d-4b5e-9326-38b8e3503dd5	65623720-4f3b-472f-9ee1-505ad5c02461	Tuesday	02:00:00	03:00:00	f	2025-11-10 11:01:03.182347
3cdb8bde-0d5f-442a-9b02-ca9d11bf55bc	65623720-4f3b-472f-9ee1-505ad5c02461	Wednesday	02:00:00	03:00:00	f	2025-11-10 11:01:03.19234
9286796b-3ba6-4589-9a93-f5b4f98bb898	65623720-4f3b-472f-9ee1-505ad5c02461	Thursday	03:00:00	04:00:00	f	2025-11-10 11:01:03.198572
4746c070-a4a7-4e36-b131-364eacaa255d	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Monday	04:00:00	10:00:00	f	2025-11-11 15:43:54.414689
3f5aeeb9-25da-48da-9453-cd2ed0f11c57	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Saturday	08:00:00	10:00:00	f	2025-10-29 13:30:17.87812
7631c545-688e-47bb-bbb3-2cefec7bd580	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Friday	13:00:00	14:00:00	f	2025-10-29 13:30:17.882078
f36a1433-6964-4e8d-90b8-a6b39b81afd9	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Tuesday	10:00:00	14:00:00	f	2025-11-11 15:43:55.017902
ff742a32-4d1b-4ba7-a62f-5b6f352dc07b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Friday	04:00:00	05:00:00	f	2025-11-11 15:43:56.518097
153357c5-6264-4501-85b3-224e86cfddf7	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	Saturday	13:00:00	14:00:00	f	2025-11-11 15:43:57.407588
0a735fe0-12e4-4287-8fca-69bca1a7b5fe	35bdfe00-4545-46f6-ad25-df895f7d4ed9	Monday	13:00:00	22:00:00	f	2025-10-22 11:31:07.134179
94873098-9a71-4789-a495-d65b374ec31f	35bdfe00-4545-46f6-ad25-df895f7d4ed9	Sunday	13:00:00	20:00:00	f	2025-10-22 11:31:07.134179
3f3ba0b6-7091-4acd-afc8-d941c07fad77	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Friday	16:00:00	18:00:00	f	2025-10-29 13:30:18.199975
acbe5b40-bccf-401b-a746-94e9046f1e58	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Thursday	06:00:00	09:00:00	f	2025-10-29 13:30:18.518382
28198434-eb43-4f8c-b6c9-d68239d441ee	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Wednesday	01:00:00	02:00:00	f	2025-10-29 13:30:18.866877
4063df5d-1c7f-4689-b5ca-7edb075a42b9	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Thursday	16:00:00	18:00:00	f	2025-10-29 13:30:19.166737
d707b67f-8725-4b48-a21b-4203fb225d60	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Sunday	08:00:00	16:00:00	f	2025-10-29 13:30:19.485277
56d674ff-f900-4808-b9ee-8536120a1746	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Wednesday	16:00:00	17:00:00	f	2025-10-29 13:30:19.791594
657e1b06-e94b-41b2-855d-1e2e7ddc714c	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Wednesday	19:00:00	23:00:00	f	2025-10-29 13:30:20.116322
c4157d6e-2605-4df0-b272-7a4edb2c28ba	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Tuesday	01:00:00	04:00:00	f	2025-10-29 13:30:21.044728
1b7a8f77-26d3-4fc8-a8d1-be1095f73457	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Tuesday	08:00:00	16:00:00	f	2025-10-29 13:30:21.360883
7a08d48c-65de-4d83-b683-40fb7389dcb4	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Friday	06:00:00	09:00:00	f	2025-10-29 13:30:21.682964
a688f36a-8b69-4101-8fb0-ccc3b4dccff1	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Thursday	06:00:00	09:00:00	f	2025-10-29 13:30:22.608839
f43b5dcb-23e7-4a1b-9766-eb857c07aad6	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Thursday	13:00:00	15:00:00	f	2025-10-29 13:30:22.936631
f27330e7-8ea0-4e9d-9597-be71084371d3	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Thursday	16:00:00	18:00:00	f	2025-10-29 13:30:23.255112
78934958-5e39-4e46-8e78-bd9077f2ea1b	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Tuesday	00:00:00	14:00:00	f	2025-10-22 11:31:07.134179
5c96882b-fe5b-4bec-8ebd-c9e7bb3687f9	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Tuesday	15:00:00	20:00:00	f	2025-10-22 11:31:07.134179
d782d857-b5f3-47c5-892e-48ee4a775e6a	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Friday	17:00:00	19:00:00	f	2025-10-22 11:31:07.134179
82224e6c-7461-4059-9810-306f2d782b39	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Saturday	00:00:00	13:00:00	f	2025-10-22 11:31:07.134179
7c42209d-6fe3-4398-8ed7-2a7b0e75ea39	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Saturday	20:00:00	23:00:00	f	2025-10-22 11:31:07.134179
908178db-c02e-489a-aaf0-7f47c144592a	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	Sunday	00:00:00	15:00:00	f	2025-10-22 11:31:07.134179
a84995c5-c036-4a15-bc39-bdcfab6df775	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	08:00:00	09:00:00	f	2025-11-03 10:31:01.099549
84b5c809-c73f-4483-969a-c8cd13dd4ca1	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Tuesday	07:00:00	09:00:00	f	2025-11-03 10:31:01.453742
81247b31-4b1e-42fc-80c9-5cd4032c720d	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	13:00:00	14:00:00	f	2025-11-03 10:31:01.885096
7aef4cde-b3bb-437d-8f6b-bee97eb3ff6b	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Tuesday	14:00:00	16:00:00	f	2025-11-03 10:31:02.250722
58a570d8-1b58-4b59-9311-a9ec73d9ca35	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	19:00:00	22:00:00	f	2025-11-03 10:31:02.569215
3b9bd709-3079-4b65-9a7d-2694c48bf6f5	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	01:00:00	02:00:00	f	2025-11-03 10:31:02.898763
a1b83598-c222-441b-910a-c83e556db400	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Friday	06:00:00	07:00:00	f	2025-11-03 10:31:03.253094
383ade1e-575f-4178-823f-0d799349376d	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	05:00:00	06:00:00	f	2025-11-03 10:31:03.587226
611fdd64-b971-410f-8cdc-83abb433e1e0	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	12:00:00	14:00:00	f	2025-11-03 10:31:03.974172
a2c3054d-aa80-444d-aeb5-f3f83c3a1067	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Friday	11:00:00	12:00:00	f	2025-11-03 10:31:03.977787
639f045e-6b07-4ce4-bce3-46a896e5d427	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	18:00:00	19:00:00	f	2025-11-03 10:31:04.328409
c7da2636-9152-468a-8e2f-a1ec93c3adb0	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Friday	14:00:00	16:00:00	f	2025-11-03 10:31:04.336946
f94b15d9-fd38-4a67-9eb4-60190e20090e	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	05:00:00	06:00:00	f	2025-11-03 10:31:04.78031
e8df28e0-080b-4b58-a2f8-3516c346bc1b	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Friday	17:00:00	20:00:00	f	2025-11-03 10:31:04.824034
03eb2321-10c6-4e02-aa25-5daf14983934	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	08:00:00	10:00:00	f	2025-11-03 10:31:05.18927
3e0892d8-ac19-4afb-813c-11dcb7115a0f	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Monday	00:00:00	01:00:00	f	2025-11-03 10:31:05.260465
dda9e693-35d3-456a-9d2b-fa59aae862e3	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Monday	04:00:00	06:00:00	f	2025-11-03 10:31:06.517782
2393ba69-8847-478e-ae3f-15be2a97046a	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	18:00:00	19:00:00	f	2025-11-03 10:31:06.831461
904c41fb-5913-4d20-805a-b9663aeb1e66	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Monday	09:00:00	11:00:00	f	2025-11-03 10:31:06.844246
83e26286-c488-4b52-866b-2a9e64f2b7b2	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Monday	14:00:00	15:00:00	f	2025-11-03 10:31:07.221523
d3f7eeb7-c4ce-4b14-8921-7d8bedcec04d	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Thursday	06:00:00	07:00:00	f	2025-11-03 10:31:07.922637
f810d0cc-21b5-457a-8bea-8082fd380015	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Thursday	08:00:00	10:00:00	f	2025-11-03 10:31:08.252243
fb1de37b-24d5-478f-9d02-5c1987231e8c	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Thursday	12:00:00	15:00:00	f	2025-11-03 10:31:08.664779
d8f9d75c-4a2d-476d-97d3-005b3fd76119	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Thursday	16:00:00	17:00:00	f	2025-11-03 10:31:09.01963
a98f4da7-d9c6-447c-af93-b210c083339c	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Thursday	18:00:00	20:00:00	f	2025-11-03 10:31:09.373377
29f02ac1-1ad4-4a32-88f3-f2f9f26b1407	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	08:00:00	09:00:00	f	2025-11-03 10:31:10.173037
bb1fcf7c-63c4-4500-bda1-6dbf58b203d8	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	11:00:00	12:00:00	f	2025-11-03 10:31:10.551826
8c1a1811-662e-435c-8454-acccf735d0ab	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	13:00:00	14:00:00	f	2025-11-03 10:31:10.946419
dab46c55-c446-4e3d-a04d-3f9f3e553ec1	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Saturday	15:00:00	16:00:00	f	2025-11-03 10:31:11.280298
5a13bc73-3942-455b-845d-d3599996ce27	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	01:00:00	02:00:00	f	2025-11-03 10:31:11.952945
4c34a852-3fb3-4b19-b6a5-217591455446	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	03:00:00	04:00:00	f	2025-11-03 10:31:12.355385
7b23e645-bef5-43d7-a700-7967885990c9	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	05:00:00	06:00:00	f	2025-11-03 10:31:12.703276
f79fad47-a697-4060-bc83-3b344917319e	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Wednesday	12:00:00	14:00:00	f	2025-11-03 10:31:13.099609
3af21ee2-fa5d-4048-9839-54eaef4d3f26	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	05:00:00	06:00:00	f	2025-11-03 10:31:14.487251
6520acc3-ff1e-4aac-9581-38933c24e14a	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	08:00:00	10:00:00	f	2025-11-03 10:31:14.810454
7a6a1ce0-1cbb-4098-a117-8ee03215b7c5	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	11:00:00	15:00:00	f	2025-11-03 10:31:15.176045
233466d7-ec90-44e2-bec9-c11a822be303	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	Sunday	18:00:00	19:00:00	f	2025-11-03 10:31:15.523201
cb5f349d-047b-4fa6-a6b1-8861c971dd18	e78c193d-617f-4e3a-b405-3b71e1c14bfd	Monday	02:00:00	09:00:00	f	2025-11-13 12:04:33.723534
357077f8-7d99-430f-9be3-8dd59c6dd2dd	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Thursday	04:00:00	10:00:00	f	2025-11-17 08:32:13.181159
67253457-d31a-4321-914b-5de4f8e1b59f	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Thursday	17:00:00	18:00:00	f	2025-11-17 08:32:13.189205
7e1e7120-dd8b-49d1-b1cf-625f72112415	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Friday	07:00:00	12:00:00	f	2025-11-17 08:32:13.196735
2b6e41a9-56b6-4596-9b86-1101ddc317bc	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Friday	14:00:00	17:00:00	f	2025-11-17 08:32:13.20373
78c05d64-25db-4f4f-b6bb-a9b19f97528a	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Wednesday	08:00:00	09:00:00	f	2025-11-17 08:32:13.209283
96ca43f7-f0a7-4277-87de-5a21ea98db16	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Wednesday	19:00:00	22:00:00	f	2025-11-17 08:32:13.215244
87011a9b-9228-4efc-991b-1137c119734a	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Tuesday	08:00:00	09:00:00	f	2025-11-17 08:32:13.220253
7c097a21-941e-4c81-983d-4dbdaef6cf3c	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Tuesday	22:00:00	23:00:00	f	2025-11-17 08:32:13.228224
0e7a37dc-064e-43b8-b3ef-e672bd549d3b	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Saturday	14:00:00	16:00:00	f	2025-11-17 08:32:13.235422
87041c93-2338-411f-8064-aff6ed95cd83	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Sunday	15:00:00	19:00:00	f	2025-11-17 08:32:13.242601
b3323ea4-2b6c-4692-be93-1f10091db0b2	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Monday	03:00:00	06:00:00	f	2025-11-18 09:01:30.424972
407e91c0-ad5a-4a00-8192-debbb411595d	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Monday	19:00:00	21:00:00	f	2025-11-18 09:01:30.432704
974f3cb3-4d76-4cb9-9d1d-3dd13205f3c7	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Wednesday	07:00:00	08:00:00	f	2025-11-18 09:01:30.438158
dbd6f2cc-b761-4935-bd77-c696f53c7401	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Wednesday	13:00:00	15:00:00	f	2025-11-18 09:01:30.443528
a75d7850-5603-42a9-a155-6dd6846c2385	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Wednesday	16:00:00	18:00:00	f	2025-11-18 09:01:30.448715
94e5068c-79fd-4f41-b17d-e8492a0823cd	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Thursday	04:00:00	06:00:00	f	2025-11-18 09:01:30.454153
acc1fe0e-b5a1-41a5-9774-2a01d4d1be7d	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Thursday	14:00:00	16:00:00	f	2025-11-18 09:01:30.460859
8091b49e-8c04-4714-831c-5249551d0765	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Thursday	17:00:00	18:00:00	f	2025-11-18 09:01:30.468059
1f5afb7b-d904-4240-9dcd-099674e44a52	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Friday	03:00:00	04:00:00	f	2025-11-18 09:01:30.473577
260c78e1-405d-403f-ad73-f1b2d1efc86c	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Friday	05:00:00	08:00:00	f	2025-11-18 09:01:30.478854
7ab67ca5-de33-4897-9168-1021145b040c	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Friday	16:00:00	20:00:00	f	2025-11-18 09:01:30.484462
4cc806e6-b156-47eb-832d-3b917429451b	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Saturday	09:00:00	10:00:00	f	2025-11-18 09:01:30.49188
fe8b5334-30eb-4140-b830-d29652de3953	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Saturday	15:00:00	16:00:00	f	2025-11-18 09:01:30.499151
6af63392-8805-41f6-8ec4-4421cbd94ed0	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Saturday	17:00:00	20:00:00	f	2025-11-18 09:01:30.505008
acd56fc4-d0ee-4925-a239-9a4814faff51	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Saturday	21:00:00	23:00:00	f	2025-11-18 09:01:30.51001
54f86f2b-8e89-4882-b10d-47683a4ab487	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Sunday	09:00:00	12:00:00	f	2025-11-18 09:01:30.522508
2652a3ee-60f9-40ac-b832-4d53596b50c7	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Tuesday	13:00:00	14:00:00	f	2025-11-18 09:01:30.532373
ca71b34c-9b96-42f7-9deb-58beecaccd9e	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Tuesday	15:00:00	16:00:00	f	2025-11-18 09:01:30.538023
ae9d95e2-ebec-4920-ae18-c71eb6037463	d30c48fa-94ab-4c6e-a72c-7b19781094db	Tuesday	09:00:00	14:00:00	f	2025-11-26 11:52:33.851863
db2ce309-6373-404e-a95a-ddf6c1e63db1	d30c48fa-94ab-4c6e-a72c-7b19781094db	Wednesday	09:00:00	14:00:00	f	2025-11-26 11:52:34.26114
f93652d9-688b-4416-85ca-9e2564a6a010	d30c48fa-94ab-4c6e-a72c-7b19781094db	Thursday	09:00:00	14:00:00	f	2025-11-26 11:52:34.581482
3af0bea9-ae3c-4dfd-a6d1-8627b04878a4	d30c48fa-94ab-4c6e-a72c-7b19781094db	Friday	09:00:00	14:00:00	f	2025-11-26 11:52:34.901937
e41223fe-4604-4b5c-a129-35d74811e7e1	d30c48fa-94ab-4c6e-a72c-7b19781094db	Monday	10:00:00	15:00:00	f	2025-11-26 11:52:35.232428
bb0db896-3304-4422-8e25-c56de1b9f9cb	ad32159d-b60a-415f-95d0-5a84548d626c	Monday	10:00:00	14:00:00	f	2025-11-26 12:11:27.159085
e4076419-713e-4991-86d5-175b9ac4085c	ad32159d-b60a-415f-95d0-5a84548d626c	Tuesday	10:00:00	14:00:00	f	2025-11-26 12:11:27.579859
57ff2e63-b143-4b2a-a380-7bb8395acb26	ad32159d-b60a-415f-95d0-5a84548d626c	Wednesday	10:00:00	14:00:00	f	2025-11-26 12:11:27.899942
5926bc40-9514-4c9d-bac0-e14ad3edd9b2	ad32159d-b60a-415f-95d0-5a84548d626c	Thursday	10:00:00	14:00:00	f	2025-11-26 12:11:28.23132
d8ba446a-af18-470f-bad4-ac4f58369078	ad32159d-b60a-415f-95d0-5a84548d626c	Friday	10:00:00	14:00:00	f	2025-11-26 12:11:28.550145
de039471-f51f-419a-9a9a-b0546a94a841	ad32159d-b60a-415f-95d0-5a84548d626c	Saturday	10:00:00	14:00:00	f	2025-11-26 12:11:28.86466
efd7d9c9-d0e5-46f9-a01c-91d70a91efa4	ad32159d-b60a-415f-95d0-5a84548d626c	Sunday	10:00:00	14:00:00	f	2025-11-26 12:11:29.185117
57a38efe-331c-41b1-93de-cc1b5567d1cf	fa649872-83b8-4f32-80be-7441feecd331	Monday	00:00:00	07:00:00	f	2025-12-16 09:33:29.959859
b47fa38e-dc8a-4c69-a768-681fed89e79c	fa649872-83b8-4f32-80be-7441feecd331	Wednesday	00:00:00	04:00:00	f	2025-12-16 09:33:30.207536
158064d2-4464-4180-87c4-4b6f0532c910	fa649872-83b8-4f32-80be-7441feecd331	Wednesday	05:00:00	07:00:00	f	2025-12-16 09:33:30.453877
9b531e65-6b1f-4dab-b7e0-d6a4d23c5700	fa649872-83b8-4f32-80be-7441feecd331	Wednesday	08:00:00	13:00:00	f	2025-12-16 09:33:30.694798
3a5b513b-9662-4eb0-b3ab-d3f0a42dc3d2	fa649872-83b8-4f32-80be-7441feecd331	Saturday	16:00:00	20:00:00	f	2025-12-16 09:33:31.417994
930ba752-62ec-411b-90e0-b59b00373583	fa649872-83b8-4f32-80be-7441feecd331	Sunday	14:00:00	17:00:00	f	2025-12-16 09:33:31.657865
839b1b36-c0c7-40be-bd0e-83ae18403c5a	fa649872-83b8-4f32-80be-7441feecd331	Thursday	12:00:00	19:00:00	f	2025-12-16 09:33:30.938531
3ef40524-ab56-4ca8-86af-abc67ab21767	fa649872-83b8-4f32-80be-7441feecd331	Friday	19:00:00	00:00:00	f	2025-12-16 09:33:31.177619
\.


--
-- Data for Name: UserFriends; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."UserFriends" (id, sender_user_id, recipient_user_id, message, status, created_at, updated_at) FROM stdin;
da074f8d-21df-4608-a293-fefa209c9d98	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	ef52ee5d-4e70-42f4-9b45-df4ec56b9682	Want to be my friend?	PENDING	2025-11-19 12:34:30.130472	2025-11-19 12:34:30.130486
5ccaab87-a097-401a-9a5a-7b5ed60721a5	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Want to be my friend?	ACCEPTED	2025-11-19 14:29:59.616048	2025-11-19 14:29:59.616061
114685e7-cb6e-43a9-8622-d1ac76635f61	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	Would you like to be my friend?	PENDING	2025-12-15 09:14:09.081411	2025-12-15 09:14:09.081424
05900eff-0ab8-4518-afa4-2e70c4ab5fd1	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	TovPlay has blocked c	BLOCKED	2025-12-15 09:15:47.543064	2025-12-15 09:15:47.543078
\.


--
-- Data for Name: UserGamePreference; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."UserGamePreference" (id, user_id, game_id) FROM stdin;
3b63cf7d-d686-489a-a400-443d42a502cf	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	d356375b-650f-4b83-8c22-ebc8310a74ef
af9a8546-85c7-4bef-ac27-acc3b4af39be	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	f7d77de5-d20e-4196-aa87-c4aa3f831d23
3cf43843-fa8f-4363-8adb-b03ab7b07beb	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	7ed96bfa-fd02-47d2-beca-39e73e689b4f
3db6c380-3045-4704-be90-d3df39ef2935	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	d356375b-650f-4b83-8c22-ebc8310a74ef
8dd7285d-4b1d-41f8-8f9e-117ce9bf7c31	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	f7d77de5-d20e-4196-aa87-c4aa3f831d23
a8af421e-de60-4cfe-912e-45d0bd46727f	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	ef9026f8-ec75-4aef-84e8-01385c0f169c
268bb79b-7519-4d32-a1fa-e6ce27894627	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	75e3f4eb-5584-4542-a68a-c06fffa9f89c
aef82772-bb76-4eed-9a2f-f08f44efe5e2	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	f7d77de5-d20e-4196-aa87-c4aa3f831d23
634aec85-f0dd-4889-b3eb-eb7e169fcad7	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	aa7a7e51-a947-4402-b46d-39b570e63ad5
f3df25a0-719d-447e-b2ae-d1d8bfc1d7d6	35bdfe00-4545-46f6-ad25-df895f7d4ed9	7ed96bfa-fd02-47d2-beca-39e73e689b4f
3c6ba37d-bb6b-4570-a7d1-b9361d9a0e4b	35bdfe00-4545-46f6-ad25-df895f7d4ed9	aa7a7e51-a947-4402-b46d-39b570e63ad5
1e62dc21-9ac4-430c-b634-72f255fd37ed	35bdfe00-4545-46f6-ad25-df895f7d4ed9	d356375b-650f-4b83-8c22-ebc8310a74ef
ff5f80e2-2f74-43f0-9ddd-8da7ea548c5b	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	aa7a7e51-a947-4402-b46d-39b570e63ad5
704f8ae0-3d6c-430e-b0ec-a8bfd91e02a5	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	f7d77de5-d20e-4196-aa87-c4aa3f831d23
fddc4585-7a48-4dd1-af11-08a1655d5774	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	f7d77de5-d20e-4196-aa87-c4aa3f831d23
4ac083f9-f0d7-4f94-a3a8-89ff56988611	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	d356375b-650f-4b83-8c22-ebc8310a74ef
e10e52f6-0871-402f-ad50-06bf0024cf78	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	69755b4c-3f27-48a1-ba17-94fdc488577c
cc3060db-089f-4a13-8cb8-2fbdd603815c	e78c193d-617f-4e3a-b405-3b71e1c14bfd	d356375b-650f-4b83-8c22-ebc8310a74ef
a8b4f464-6c94-482e-a9ca-d2a6ecf01912	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	80315b4a-b6d2-492b-8b13-089b07feb31c
6b435493-1000-4788-b454-6c9ea6f399d5	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	a05e3b94-7404-4c1b-819a-2ef5fee2ba27
67b62c3f-cb32-4d5f-ad52-ee88aa8c4679	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	d356375b-650f-4b83-8c22-ebc8310a74ef
669d701e-25f3-418f-a95d-d6fb925412b8	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	7ed96bfa-fd02-47d2-beca-39e73e689b4f
7336dae2-9526-42b0-b3e2-e301ba19a09d	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	69755b4c-3f27-48a1-ba17-94fdc488577c
ac731fae-32a6-450a-b0fd-924210898538	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	80315b4a-b6d2-492b-8b13-089b07feb31c
26df051a-3329-420d-b4e6-deb87faef98f	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	ef9026f8-ec75-4aef-84e8-01385c0f169c
d1edc453-35ee-4032-b85c-493e857a0271	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	f7d77de5-d20e-4196-aa87-c4aa3f831d23
2f747190-6855-4d8d-8a73-729c52b75b50	d30c48fa-94ab-4c6e-a72c-7b19781094db	d356375b-650f-4b83-8c22-ebc8310a74ef
f1d251af-8223-4645-b796-ebddde7feadf	d30c48fa-94ab-4c6e-a72c-7b19781094db	7ed96bfa-fd02-47d2-beca-39e73e689b4f
001e766c-b45b-475f-af20-7b73eaea8d5f	ad32159d-b60a-415f-95d0-5a84548d626c	d356375b-650f-4b83-8c22-ebc8310a74ef
a5bd6e98-ef35-4eaa-8184-48af871c68cf	ad32159d-b60a-415f-95d0-5a84548d626c	f7d77de5-d20e-4196-aa87-c4aa3f831d23
5f9eb51c-fa41-437d-b510-26dc2ee1c834	ad32159d-b60a-415f-95d0-5a84548d626c	7ed96bfa-fd02-47d2-beca-39e73e689b4f
8d56c604-e675-4764-9e7f-4e8b7d8c7126	fa649872-83b8-4f32-80be-7441feecd331	d356375b-650f-4b83-8c22-ebc8310a74ef
e712fe7e-ea22-4bdc-b461-8d53a787b48b	fa649872-83b8-4f32-80be-7441feecd331	f7d77de5-d20e-4196-aa87-c4aa3f831d23
78215871-d597-4ead-9417-b6ca5a555ac2	fa649872-83b8-4f32-80be-7441feecd331	80315b4a-b6d2-492b-8b13-089b07feb31c
\.


--
-- Data for Name: UserNotifications; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."UserNotifications" (id, user_id, title, message, is_read, created_at) FROM stdin;
1315addd-e583-49ca-8b4d-525d94d8234d	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 01:00	f	2025-11-18 12:00:46.404634
5b54d5df-fa81-4514-ae97-93162b6f569e	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	Invitation accepted	Game Stardew Valley with TovPlay (scheduled at 2025-11-20 04:00:00) was accepted	f	2025-11-18 12:30:55.099393
a7bf0696-c93a-4dbe-b062-1010e24f2bd3	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	You have accepted an invitation	You accepted lilach0492's invitation to play Stardew Valley  at 2025-11-20 04:00:00	f	2025-11-18 12:30:55.099413
3786db50-60eb-4adc-98ab-4431b8c3691e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 02:00	f	2025-11-18 12:41:54.829844
267a73c0-4319-4a6a-b23d-9c1da0bc0fca	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 03:00	f	2025-11-18 12:42:28.181768
2aae2a69-7672-4f1c-9e64-4517a0c97838	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	e has invited you to play Chess  at 2025-11-24T02:00:00+02:00	f	2025-11-18 12:47:18.290927
59ada6dc-5d9c-491d-b79c-a365a8dee350	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	New game request	d has invited you to play Chess  at 2025-11-19T13:00:00+02:00	f	2025-11-18 12:52:04.867353
54e5a09b-455d-413c-8b86-f342c90bcc74	ef52ee5d-4e70-42f4-9b45-df4ec56b9682	New friend request from lil	Want to be my friend?	f	2025-11-19 12:34:30.223036
6b916ed1-2dd9-4189-bd2f-3cf81eb7411a	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	New friend request from lilach0492	Want to be my friend?	f	2025-11-19 12:35:29.452183
962c2afd-3cb1-4ede-abfa-5a3a2fb12ba2	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	Friend request accepted	Your friend request to 'lilach0492' was accepted!	f	2025-11-19 12:49:35.122294
6063fdad-16c4-43f7-ba65-33355e86eeec	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	You have accepted an invitation	You are now friends with 'TovPlay'!	f	2025-11-19 12:49:35.12232
e01bb34f-7873-4b46-84a2-2ca881982e93	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	New friend request from TovPlay	Want to be my friend?	f	2025-11-19 14:29:59.718006
be7c9407-91e4-4f50-8673-2c0e30057b22	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 04:00	f	2025-11-20 09:16:38.691312
a9733a82-5a27-45bd-9227-4a4570a90db6	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-20T21:00:00Z	f	2025-11-20 10:15:04.214172
3b83a1c6-d465-4feb-87bd-20bd2c6b6597	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 05:00	f	2025-11-20 10:18:46.826476
685b4997-05d2-45c7-84b8-c37fd54dfb8a	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-20T22:00:00Z	f	2025-11-20 10:21:45.168907
8f68ba3d-f78a-4d58-b265-2b1ecad3569e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-20T23:00:00Z	f	2025-11-20 10:23:04.411341
b9cd652c-33a3-4439-b4a0-8ea0b4b9b7af	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-20T24:00:00Z	f	2025-11-20 10:23:51.169656
807c5e83-d17e-423e-9c41-2ba7ac1c3161	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 06:00	f	2025-11-20 10:40:00.676813
51e7aa5e-f7e5-422f-ad3f-5b70190c1ab8	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T01:00:00Z	f	2025-11-20 10:42:48.816008
f44c6cc8-94ce-46db-87cc-646a5400e1a8	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 00:00:00", "requestId": "15069e90-8343-4248-a310-ac57d17e4fcc", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:23:51.095781", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:23:51.97943
9716d68b-fcaf-4040-810b-44413cf6d9e3	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-20 23:00:00", "requestId": "0ccd9a35-56fb-4e96-854e-873569053901", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:23:04.342952", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:23:04.886485
64b88d63-6917-42b5-995c-67114eebdf9f	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-20 22:00:00", "requestId": "22bf7920-ed98-45cd-a1a2-fcbf70a5bebd", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:21:45.096769", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:21:45.65413
979c3b48-1bb0-4c76-b5bb-97d04ea4132c	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 05:00:00", "requestId": "9e6b55e4-4625-42fa-9be6-2b9af6dfc325", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:18:46.754490", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:18:47.615354
b4535369-dc39-4336-9c16-b3701a39bdcb	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-20 21:00:00", "requestId": "bf37e40e-d9da-42eb-bcab-47e9d9c52376", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:15:04.142155", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:15:04.687779
e46f9519-412e-4650-b09f-492dbc792051	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 04:00:00", "requestId": "2414c669-3824-44e7-b4c0-580530a754b2", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 09:16:38.619624", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 09:16:39.185616
a13c0b3a-1e38-460e-8e8d-e605b6ad2bec	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 03:00:00", "requestId": "7f0815c5-44dd-4bfb-a965-50d1fa5a8073", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-18 12:42:28.114309", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-18 12:42:28.65705
7acd8cdb-3884-4551-a25d-4c6d45a1685b	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 02:00:00", "requestId": "3af88191-f76a-4841-84d5-4efeea4c3fe9", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-18 12:41:54.758996", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-18 12:41:55.298435
615b4530-8d98-47a3-bda5-dc507c33b35f	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 01:00:00", "requestId": "fc0c7753-93fb-45ef-b19f-dffa0b84deee", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-18 12:00:46.330486", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-18 12:00:46.886484
cb20b57c-5db2-4fdd-a86d-fbef91db915e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T02:00:00Z	f	2025-11-20 10:44:15.005501
f732d7a0-327b-4e29-8324-fa33a919b9ae	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 07:00	f	2025-11-20 10:50:07.376348
f91679d7-4211-4cf7-8bca-98746aa51663	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T03:00:00Z	f	2025-11-20 10:51:45.112184
c6ee4cd5-ea1b-4595-adee-1205be1069ea	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 08:00	f	2025-11-20 10:55:59.913612
f25cc732-1aad-435d-9bb3-8030941385f2	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T04:00:00Z	f	2025-11-20 10:56:59.843443
2f463876-6cf9-44ab-914e-8b314c7c60a9	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 10:00	f	2025-11-20 10:58:40.576476
cf5d46f7-e876-4fb5-8d12-7e37cc94783e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T05:00:00Z	f	2025-11-20 11:00:01.014006
bc80f205-a951-4ddd-8ec1-18093421b278	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T06:00:00Z	f	2025-11-20 11:00:26.747723
321e9f56-6d1c-4473-8519-5da9ee833669	35bdfe00-4545-46f6-ad25-df895f7d4ed9	New game request	e has invited you to play Chess  at 2025-11-19T09:00:00+02:00	t	2025-11-18 12:52:57.026899
c1d33934-511e-447b-895e-e4fc86436701	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	New game request	d has invited you to play Chess  at 2025-11-23T15:00:00+02:00	f	2025-11-20 12:17:26.584606
ac5eb841-8c32-4dd7-ad26-76ec25231f7f	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 11:00	f	2025-11-20 12:33:10.082925
9a1258db-1d3f-49c7-9511-0f831d818fbd	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21T07:00:00Z	f	2025-11-20 12:50:08.333535
eba4f12a-2d9c-4789-aec3-5af11cd48a7a	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 12:00	f	2025-11-20 12:51:14.587567
18f5688d-6ef0-4209-a7dc-bb7040b1bd7c	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 07:00:00", "requestId": "42354466-970a-41cd-af70-2dc29c84bffc", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 12:50:08.259235", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 12:50:08.837651
b524cd93-d216-45aa-abb7-76ab2f748d5a	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 11:00:00", "requestId": "9511735c-8660-4fe2-add8-9bcff977b6e6", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 12:33:10.010371", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 12:33:10.838214
abfb12cd-20f7-4c17-8c5e-2aa63cb92c52	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 06:00:00", "requestId": "aa052ba2-94e0-4b21-9c4a-6996c561112b", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 11:00:26.680506", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 11:00:27.226955
6d39e729-114b-4a85-904f-3c1294d67901	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 05:00:00", "requestId": "85a586b8-7729-4333-8337-cfd7de4452a6", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 11:00:00.944089", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 11:00:01.492025
fecb700f-b09b-499a-8a83-317955ebd34b	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 10:00:00", "requestId": "35ec5862-5d51-4e88-a1de-ca325e8049d2", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:58:40.506613", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:58:41.053972
3d329d72-32f8-455b-abe5-785a4448d671	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 04:00:00", "requestId": "24190ba5-9202-4840-9003-d51d5d0e5ad9", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:56:59.772064", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:57:00.325098
34196afb-b9e8-44f2-b099-a126719ce99c	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 08:00:00", "requestId": "e64a296a-172b-4b2b-94f2-1792309cef45", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:55:59.841700", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:56:00.690759
84106d46-8e45-4538-985c-2a4203e628b8	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 03:00:00", "requestId": "6f8b282b-76a7-410c-8785-c6a517d0a408", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:51:45.036553", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:51:45.626927
6db3a9dc-da41-488d-99ba-fcd1f4717015	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 07:00:00", "requestId": "c3a8ff9b-2a12-4474-9cb1-610916eb8328", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:50:07.304364", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:50:08.204618
e99e8984-df6d-4c13-a63b-bb9a2cfcb6fd	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 02:00:00", "requestId": "cb22563d-998b-4ebc-b0e8-dbccabe5a48e", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:44:14.928125", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:44:15.496054
7af74430-f9ec-4b5e-8bdf-bdd05daaaf1f	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 01:00:00", "requestId": "b1b60f8f-f99c-449e-8738-71b3ac0240a4", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:42:48.743306", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:42:49.329634
679bcc5b-581a-4cff-96d3-0ed0a4c91fb3	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 13:00	f	2025-11-20 15:31:03.582661
da7fdd29-52bd-46d0-b258-e00e140cddbc	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 14:00	f	2025-11-20 15:44:51.096466
fbaebd4d-7ef7-4683-bff7-ea3ba078c9b8	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 15:00	f	2025-11-20 17:44:42.902366
d63ba84b-831e-4abf-abc8-f6b26378bdf1	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 16:00	f	2025-11-21 09:55:57.033626
d028cbfc-22aa-4d86-b1d6-74453806f1a6	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-18 00:00	f	2025-11-21 10:07:21.126723
9b30cfad-0362-472f-8c69-84837c448063	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-17 17:00	f	2025-11-21 22:08:16.085644
95e48d8f-4a0e-4013-a18a-373978bb8a98	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21 10:00	f	2025-11-22 00:26:03.246288
d2edb394-e878-44ad-96ef-728757ac7559	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21 11:00	f	2025-11-22 00:28:52.149809
6e964106-a2b9-4783-99a6-ed376dfebfc0	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-21 13:00	f	2025-11-22 00:32:22.807449
94966458-25a2-44ce-9e74-2c67878c6fd7	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-25 00:00	f	2025-11-22 00:43:05.254198
9dc9e874-327a-488a-8d9a-4ef142db82be	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-26 00:00	f	2025-11-22 00:43:58.40442
d822f811-31a8-4866-9086-6febe948bcf6	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-28 00:00	f	2025-11-22 00:45:26.74181
8bb7b4b8-471d-424b-a469-f4b71c702aa6	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-29 00:00	f	2025-11-22 00:46:41.712663
8917908a-6aec-46f9-8916-28477eae1753	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-26 00:00:00", "requestId": "77bfa5d8-12b3-4385-938c-d14c55df96b2", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:43:58.331045", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:43:58.876856
f80b06a5-763c-4fbf-b15e-aeefc3171744	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-25 00:00:00", "requestId": "e209f790-eeea-4f5f-bc0a-c5cc94c371d9", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:43:05.179798", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:43:05.765512
d4a896b4-8eea-4c76-9eab-f46a69d02207	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 13:00:00", "requestId": "4e8e1ce0-77a4-40c6-b91a-9187736d7838", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:32:22.736337", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:32:23.289462
f58e805b-dba4-4686-9492-fc1796f07fdd	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 11:00:00", "requestId": "9fe381d4-b200-40af-a617-1e679a306967", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:28:52.079219", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:28:52.648022
df168c3f-6b03-496a-80ce-b692c9c08e0e	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-21 10:00:00", "requestId": "f9d41e64-ecf2-4216-b4e5-4761d77a4a75", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:26:03.170303", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:26:03.735555
92ec36e7-609e-4dbf-8534-9d7a1415b5a8	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 17:00:00", "requestId": "08a17cca-21c5-4675-abf7-ca6016ca84e4", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-21 22:08:16.015425", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-21 22:08:16.572157
85b09dc5-f1d8-44c8-a6b5-e3fe51c59be9	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-18 00:00:00", "requestId": "4dcdca2e-8312-4996-bcb1-3743a1c5d529", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-21 10:07:21.048098", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-21 10:07:21.646424
07b7e20c-3f06-4508-93e7-8b0c8ac06763	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 16:00:00", "requestId": "da37398c-5737-44f9-9118-f3f776846b5b", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-21 09:55:56.950024", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-21 09:55:57.569345
2e1225ab-1085-43df-8427-3ce9e2d8993d	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 15:00:00", "requestId": "f7a77d55-5c79-4134-827d-83b2b210c21c", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 17:44:42.829497", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 17:44:43.38873
38c139c3-e6f0-4662-9cb9-292e7198a220	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 14:00:00", "requestId": "bfa933b9-b9fd-48f8-aad9-40e11dab843c", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 15:44:51.024612", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 15:44:51.873568
98147bb2-0757-4a75-a9a7-cd47a765697c	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 13:00:00", "requestId": "7f34d1d3-3177-4daa-a315-8b48a738e3ee", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 15:31:03.502450", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 15:31:04.087745
0b0826cf-cc6b-4968-979c-5cd3d9e88137	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-30 00:00	f	2025-11-22 00:47:50.794783
f9653032-a593-4dbd-bf8b-8a7133a0f0ef	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-30 00:00:00", "requestId": "a63bd2ca-e5c5-4f1b-85ca-1068738f5b01", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:47:50.724493", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:47:51.409962
e6f01a0c-44b2-443b-ac10-9aa3725e9240	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-29 00:00:00", "requestId": "1d2c7032-cf4c-4451-b16b-1ad1f1071807", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:46:41.631074", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:46:42.196339
fe5e19dc-3b50-4ba0-84b8-c9cbd799f003	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-28 00:00:00", "requestId": "ca8744ff-c842-4367-b03c-7d88c4b5b256", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-22 00:45:26.670844", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-22 00:45:27.21445
a17df268-8e4f-45aa-bcec-b2ce194d4616	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 12:00:00", "requestId": "f6bc1c29-20a7-4863-8fbe-ef3b2b9cc229", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 12:51:14.515324", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 12:51:15.062004
22f47d7f-0326-4da8-bce9-a9490c5a5883	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-17 06:00:00", "requestId": "79ef469f-1e6a-4c14-a566-d00d7997c5b9", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-20 10:40:00.601309", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-20 10:40:01.517786
a23ee620-c318-44e3-92a2-2dc02fee031b	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-18 01:00	f	2025-11-26 10:16:06.701585
410e0388-c0f0-483a-bea6-c5f590742d33	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-18 01:00:00", "requestId": "617fd7c8-0bff-4eae-abe6-7f0d1d6ae264", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-26 10:16:06.629106", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	t	2025-11-26 10:16:07.195788
80b37939-93a8-46d1-a826-aae4617485da	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New game request	CozyGamer has invited you to play Chess  at 2025-11-18 02:00	f	2025-11-26 10:18:59.522881
9fadfad2-f553-4e93-8b38-c445cabc598b	e78c193d-617f-4e3a-b405-3b71e1c14bfd	New Game Request	{"type": "game_request", "payload": "new", "game_id": "d356375b-650f-4b83-8c22-ebc8310a74ef", "game_name": "Chess", "suggested_time": "2025-11-18 02:00:00", "requestId": "9a776b35-9d2a-43c3-8af5-20865d8d3a30", "user_id": "dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e", "user_name": "CozyGamer", "created_at": "2025-11-26 10:18:59.454201", "is_read": false, "recipient_user_id": "e78c193d-617f-4e3a-b405-3b71e1c14bfd"}	f	2025-11-26 10:19:00.336827
56991b58-d3c9-41ea-8c36-717984e1aa26	d30c48fa-94ab-4c6e-a72c-7b19781094db	New game request	Xddd has invited you to play Chess  at 2025-12-03T10:00:00+02:00	t	2025-11-26 12:12:06.513385
d4fcfe13-65cb-43d7-b54a-4f8931f00451	d30c48fa-94ab-4c6e-a72c-7b19781094db	New game request	Xddd has invited you to play Minecraft  at 2025-12-03T11:00:00+02:00	f	2025-11-26 12:15:29.845503
27992e7b-b8c5-48b8-9894-de56bc7685f3	d30c48fa-94ab-4c6e-a72c-7b19781094db	New game request	Xddd has invited you to play Minecraft  at 2025-12-03T12:00:00+02:00	f	2025-11-26 12:15:30.144623
098e6966-a99b-47f6-831e-f84d707c382c	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	New game request	Roman has invited you to play Chess  at 2025-11-26T13:00:00+02:00	f	2025-11-26 12:16:06.348571
9e09722f-29c5-404d-aef9-7266a30e6a29	c0367e50-b52c-4e8e-b1ee-aac24a26aa99	New game request	Roman has invited you to play Chess  at 2025-12-02T13:00:00+02:00	f	2025-11-26 12:16:06.655358
1be71243-e049-48da-9247-ddcc922bf2d2	ad32159d-b60a-415f-95d0-5a84548d626c	Invitation accepted	Game Minecraft with Roman (scheduled at 2025-12-03 11:00:00) was accepted	f	2025-11-26 12:33:49.76278
f4f0edcb-ea7f-4fc6-b187-e0b299c109a7	d30c48fa-94ab-4c6e-a72c-7b19781094db	You have accepted an invitation	You accepted Xddd's invitation to play Minecraft  at 2025-12-03 11:00:00	f	2025-11-26 12:33:49.762785
71fb65ee-3414-4d82-9a69-efa8383eea83	ad32159d-b60a-415f-95d0-5a84548d626c	Game session cancelled	You have cancelled a session with 'Xddd' playing Minecraft  at 2025-12-03 11:00:00). The message you sent: tgeg	f	2025-11-26 12:47:06.410824
e67b66db-11a8-4799-894d-06499073e6cc	ad32159d-b60a-415f-95d0-5a84548d626c	Game session cancelled	'Roman' has cancelled a session playing Minecraft at 2025-12-03 11:00:00). message:tgeg	f	2025-11-26 12:47:10.670272
90605f62-3a0c-4009-a011-05b1f863bfb7	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	New game request	Xddd has invited you to play Chess  at 2025-11-28T10:00:00+02:00	f	2025-11-26 12:47:47.09917
c0f1af3e-3880-499c-8c48-133518d3bbae	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2	New game request	Xddd has invited you to play Chess  at 2025-11-28T11:00:00+02:00	f	2025-11-26 12:47:47.366777
1e78a7f7-ae30-4a25-ba93-9ce2a0a2bf94	d30c48fa-94ab-4c6e-a72c-7b19781094db	New game request	Xddd has invited you to play Chess  at 2025-12-03T11:00:00+02:00	f	2025-11-26 12:47:59.3902
791f3ffe-dc92-48c3-8eb1-df510801c56f	d30c48fa-94ab-4c6e-a72c-7b19781094db	New game request	Xddd has invited you to play Chess  at 2025-11-26T13:00:00+02:00	f	2025-11-26 12:47:59.6254
fa69d864-2bc4-439f-8a3c-c368d5459e37	d30c48fa-94ab-4c6e-a72c-7b19781094db	New game request	Xddd has invited you to play Chess  at 2025-12-03T12:00:00+02:00	f	2025-11-26 12:47:59.625795
db07bc14-ac39-4acd-9aeb-c4dfec0ab58c	ad32159d-b60a-415f-95d0-5a84548d626c	Invitation accepted	Game Chess with Roman (scheduled at 2025-11-26 13:00:00) was accepted	f	2025-11-26 12:48:52.603333
295e21f4-70b0-4ad8-bfb0-2790f6c16707	d30c48fa-94ab-4c6e-a72c-7b19781094db	You have accepted an invitation	You accepted Xddd's invitation to play Chess  at 2025-11-26 13:00:00	f	2025-11-26 12:48:52.603338
0c9ddb8e-159c-4186-8431-1f939aaf52d4	ad32159d-b60a-415f-95d0-5a84548d626c	Invitation accepted	Game Chess with Roman (scheduled at 2025-12-03 11:00:00) was accepted	f	2025-11-26 12:52:28.95945
8238baec-e971-4f7c-9f87-1f85caae620a	d30c48fa-94ab-4c6e-a72c-7b19781094db	You have accepted an invitation	You accepted Xddd's invitation to play Chess  at 2025-12-03 11:00:00	f	2025-11-26 12:52:28.959455
2bee8b11-fec2-4290-ade4-b063e058cb42	ad32159d-b60a-415f-95d0-5a84548d626c	Game session cancelled	You have cancelled a session with 'Xddd' playing Chess  at 2025-12-03 11:00:00). The message you sent: I can't play	f	2025-11-26 13:35:05.624358
4fab9120-b2f4-48a2-b337-3deee6d7a16d	ad32159d-b60a-415f-95d0-5a84548d626c	Game session cancelled	'Roman' has cancelled a session playing Chess at 2025-12-03 11:00:00). message:I can't play	f	2025-11-26 13:35:09.92829
cb78bc38-2889-4750-bd40-ba209022e793	ad32159d-b60a-415f-95d0-5a84548d626c	Invitation accepted	Game Chess with Roman (scheduled at 2025-12-03 12:00:00) was accepted	f	2025-11-26 13:35:48.296143
ac6b3c52-ca49-4b8d-b586-623d1b89c3ae	d30c48fa-94ab-4c6e-a72c-7b19781094db	You have accepted an invitation	You accepted Xddd's invitation to play Chess  at 2025-12-03 12:00:00	f	2025-11-26 13:35:48.296148
13b0f40d-e243-41c0-bf72-f8bb540d2d1b	ad32159d-b60a-415f-95d0-5a84548d626c	Game session cancelled	You have cancelled a session with 'Xddd' playing Chess  at 2025-12-03 12:00:00). The game session has been canceled.	f	2025-11-26 13:35:59.356469
c763b6a0-d402-4947-80a2-fc4e54d0e856	ad32159d-b60a-415f-95d0-5a84548d626c	Game session cancelled	'Roman' has cancelled a session playing Chess at 2025-12-03 12:00:00). message:The game session has been canceled	f	2025-11-26 13:36:03.638837
ebf1f331-9310-4c26-aaa7-a8e24bcdd37c	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	New friend request from b	Would you like to be my friend?	f	2025-12-15 09:14:09.151075
\.


--
-- Data for Name: UserProfile; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."UserProfile" (id, user_id, bio, avatar_url, language, timezone, communication_preferences, updated_at) FROM stdin;
3051c06f-8a0a-485e-bff0-033db8e69f8f	04ffeddb-f14c-4a7a-930b-b06175b3dc4d	HI there!!	https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{he,en,ar}	\N	Voice	2025-11-11 16:16:00.388612
87b1ef9c-5275-443c-a21e-a5f7ccfc65d2	a4dc94f1-a3cb-4ba5-956b-91165d88e0dd	I love to play fantasy RPGs!	https://example.com/avatars/john.jpg	{en,ru,he}	America/New_York	NoTalking	2025-11-11 16:16:26.403334
f8703984-da49-4567-ae5a-a909e04112ce	b7973fc9-8cdf-4ae0-8a33-f7ab180df983	HI there!! Let's play some amazing game		{he,en,ru}	\N	Voice	2025-11-11 17:46:20.029341
07e0f406-cca8-42bc-b8ab-b63cba650ba3	35bdfe00-4545-46f6-ad25-df895f7d4ed9	HI there!! Let's play some amazing game	https://api.dicebear.com/9.x/bottts-neutral/svg?seed=Brian	{he,en,ru}	\N	Written	2025-11-11 17:46:44.491386
3b5567ad-f9a1-4220-a502-cc22d9b5657c	dc56acaa-20b8-4b6d-b8fd-0637bbe9d54e	HI there!! Let's play some amazing game		{he,en,ru}	\N	Voice	2025-11-11 17:52:07.743418
7377e417-f1cc-40ab-8b66-6be2fa44bb0e	ef52ee5d-4e70-42f4-9b45-df4ec56b9682	HI there!! Let's play some amazing game		{he,en,ru}	\N	Voice	2025-11-11 16:53:09.292897
7f69dedc-9ce4-4bec-b69b-4aaaeacfa8cc	db27ffc7-7e19-4b0d-93c7-09d86e6b68f2		https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{he,en}	\N	Voice	2025-11-13 11:31:49.555784
4d54226f-fc8e-43b4-b64c-d779251c7915	e78c193d-617f-4e3a-b405-3b71e1c14bfd		https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{}	\N	Written	2025-11-13 13:05:06.583452
6fcc156e-8735-4024-8778-72dccb9f7eb5	c0367e50-b52c-4e8e-b1ee-aac24a26aa99		https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{he,en}	\N	Voice	2025-11-18 12:01:52.884597
f75392d9-3bae-4324-9ca8-3443d4d1b811	d30c48fa-94ab-4c6e-a72c-7b19781094db		https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{en,he,ru}	\N	Voice	2025-11-26 12:52:51.047008
c74ba724-6d54-408d-9df3-ebf9cc1607f8	ad32159d-b60a-415f-95d0-5a84548d626c		https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{he,en}	\N	Voice	2025-11-26 13:11:44.786455
330137ee-b1a9-45b1-aad7-843ecef98c12	fa649872-83b8-4f32-80be-7441feecd331		https://api.dicebear.com/9.x/thumbs/svg?seed=Jessica	{en,he}	\N	Written	2025-12-16 11:32:46.27976
\.


--
-- Data for Name: UserSession; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public."UserSession" (id, user_id, session_token, expires_at, last_activity, user_agent, ip_address) FROM stdin;
\.


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public.alembic_version (version_num) FROM stdin;
9dde41419c52
\.


--
-- Data for Name: auditlog; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public.auditlog (id, event_timestamp, table_name, operation, affected_rows, user_account, user_ip, error_details, session_id) FROM stdin;
\.


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: raz@tovtech.org
--

COPY public.password_reset_tokens (id, user_id, token, created_at, used) FROM stdin;
1	ff07e8f3-a942-4c8e-abdf-11d036aad886	InV2LnpleWdlckBnbWFpbC5jb20i.aRrdCg.tWHbDZVCFx9IKa7aVKDxCb2OK_E	2025-11-17 08:30:02.087294+00	t
3	389bad2c-cbbf-4539-9f96-17afca8ce233	ImtlcmVud2VkZWxAZ21haWwuY29tIg.aR7aKg.xCWeQK1xb56o9E7GVPMzVhmJxjs	2025-11-20 09:06:50.164156+00	f
\.


--
-- Name: BackupLog_id_seq; Type: SEQUENCE SET; Schema: public; Owner: raz@tovtech.org
--

SELECT pg_catalog.setval('public."BackupLog_id_seq"', 3, true);


--
-- Name: ConnectionAuditLog_id_seq; Type: SEQUENCE SET; Schema: public; Owner: raz@tovtech.org
--

SELECT pg_catalog.setval('public."ConnectionAuditLog_id_seq"', 1, false);


--
-- Name: DeleteAuditLog_id_seq; Type: SEQUENCE SET; Schema: public; Owner: raz@tovtech.org
--

SELECT pg_catalog.setval('public."DeleteAuditLog_id_seq"', 1, true);


--
-- Name: ProtectionStatus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: raz@tovtech.org
--

SELECT pg_catalog.setval('public."ProtectionStatus_id_seq"', 1, true);


--
-- Name: auditlog_id_seq; Type: SEQUENCE SET; Schema: public; Owner: raz@tovtech.org
--

SELECT pg_catalog.setval('public.auditlog_id_seq', 1, false);


--
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: raz@tovtech.org
--

SELECT pg_catalog.setval('public.password_reset_tokens_id_seq', 3, true);


--
-- Name: BackupLog BackupLog_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."BackupLog"
    ADD CONSTRAINT "BackupLog_pkey" PRIMARY KEY (id);


--
-- Name: ConnectionAuditLog ConnectionAuditLog_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ConnectionAuditLog"
    ADD CONSTRAINT "ConnectionAuditLog_pkey" PRIMARY KEY (id);


--
-- Name: DeleteAuditLog DeleteAuditLog_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."DeleteAuditLog"
    ADD CONSTRAINT "DeleteAuditLog_pkey" PRIMARY KEY (id);


--
-- Name: EmailVerification EmailVerification_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."EmailVerification"
    ADD CONSTRAINT "EmailVerification_pkey" PRIMARY KEY (id);


--
-- Name: GameRequest GameRequest_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."GameRequest"
    ADD CONSTRAINT "GameRequest_pkey" PRIMARY KEY (id);


--
-- Name: Game Game_game_name_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."Game"
    ADD CONSTRAINT "Game_game_name_key" UNIQUE (game_name);


--
-- Name: Game Game_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."Game"
    ADD CONSTRAINT "Game_pkey" PRIMARY KEY (id);


--
-- Name: ProtectionStatus ProtectionStatus_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ProtectionStatus"
    ADD CONSTRAINT "ProtectionStatus_pkey" PRIMARY KEY (id);


--
-- Name: ScheduledSession ScheduledSession_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ScheduledSession"
    ADD CONSTRAINT "ScheduledSession_pkey" PRIMARY KEY (id);


--
-- Name: UserAvailability UserAvailability_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserAvailability"
    ADD CONSTRAINT "UserAvailability_pkey" PRIMARY KEY (id);


--
-- Name: UserFriends UserFriends_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserFriends"
    ADD CONSTRAINT "UserFriends_pkey" PRIMARY KEY (id);


--
-- Name: UserGamePreference UserGamePreference_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserGamePreference"
    ADD CONSTRAINT "UserGamePreference_pkey" PRIMARY KEY (id);


--
-- Name: UserNotifications UserNotifications_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserNotifications"
    ADD CONSTRAINT "UserNotifications_pkey" PRIMARY KEY (id);


--
-- Name: UserProfile UserProfile_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserProfile"
    ADD CONSTRAINT "UserProfile_pkey" PRIMARY KEY (id);


--
-- Name: UserProfile UserProfile_user_id_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserProfile"
    ADD CONSTRAINT "UserProfile_user_id_key" UNIQUE (user_id);


--
-- Name: UserSession UserSession_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserSession"
    ADD CONSTRAINT "UserSession_pkey" PRIMARY KEY (id);


--
-- Name: User User_discord_id_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_discord_id_key" UNIQUE (discord_id);


--
-- Name: User User_discord_username_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_discord_username_key" UNIQUE (discord_username);


--
-- Name: User User_email_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_email_key" UNIQUE (email);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: User User_username_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_username_key" UNIQUE (username);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: auditlog auditlog_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.auditlog
    ADD CONSTRAINT auditlog_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_token_key UNIQUE (token);


--
-- Name: EmailVerification audit_del_emailverification; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_emailverification BEFORE DELETE ON public."EmailVerification" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: Game audit_del_game; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_game BEFORE DELETE ON public."Game" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: GameRequest audit_del_gamerequest; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_gamerequest BEFORE DELETE ON public."GameRequest" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: ScheduledSession audit_del_scheduledsession; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_scheduledsession BEFORE DELETE ON public."ScheduledSession" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: User audit_del_user; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_user BEFORE DELETE ON public."User" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: UserAvailability audit_del_useravailability; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_useravailability BEFORE DELETE ON public."UserAvailability" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: UserFriends audit_del_userfriends; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_userfriends BEFORE DELETE ON public."UserFriends" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: UserGamePreference audit_del_usergamepreference; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_usergamepreference BEFORE DELETE ON public."UserGamePreference" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: UserNotifications audit_del_usernotifications; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_usernotifications BEFORE DELETE ON public."UserNotifications" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: UserProfile audit_del_userprofile; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_userprofile BEFORE DELETE ON public."UserProfile" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: UserSession audit_del_usersession; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER audit_del_usersession BEFORE DELETE ON public."UserSession" FOR EACH ROW EXECUTE FUNCTION public.audit_delete_fn();


--
-- Name: EmailVerification block_mass_delete_emailverification; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_emailverification AFTER DELETE ON public."EmailVerification" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: Game block_mass_delete_game; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_game AFTER DELETE ON public."Game" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: GameRequest block_mass_delete_gamerequest; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_gamerequest AFTER DELETE ON public."GameRequest" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: ScheduledSession block_mass_delete_scheduledsession; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_scheduledsession AFTER DELETE ON public."ScheduledSession" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: User block_mass_delete_user; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_user AFTER DELETE ON public."User" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserAvailability block_mass_delete_useravailability; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_useravailability AFTER DELETE ON public."UserAvailability" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserFriends block_mass_delete_userfriends; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_userfriends AFTER DELETE ON public."UserFriends" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserGamePreference block_mass_delete_usergamepreference; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_usergamepreference AFTER DELETE ON public."UserGamePreference" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserNotifications block_mass_delete_usernotifications; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_usernotifications AFTER DELETE ON public."UserNotifications" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserProfile block_mass_delete_userprofile; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_userprofile AFTER DELETE ON public."UserProfile" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserSession block_mass_delete_usersession; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_mass_delete_usersession AFTER DELETE ON public."UserSession" REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE FUNCTION public.block_mass_delete();


--
-- Name: UserAvailability block_truncate_availability; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_availability BEFORE TRUNCATE ON public."UserAvailability" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: EmailVerification block_truncate_emailverification; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_emailverification BEFORE TRUNCATE ON public."EmailVerification" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserFriends block_truncate_friends; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_friends BEFORE TRUNCATE ON public."UserFriends" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: Game block_truncate_game; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_game BEFORE TRUNCATE ON public."Game" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserGamePreference block_truncate_gamepref; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_gamepref BEFORE TRUNCATE ON public."UserGamePreference" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: GameRequest block_truncate_gamerequest; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_gamerequest BEFORE TRUNCATE ON public."GameRequest" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserNotifications block_truncate_notifications; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_notifications BEFORE TRUNCATE ON public."UserNotifications" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserProfile block_truncate_profile; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_profile BEFORE TRUNCATE ON public."UserProfile" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: ScheduledSession block_truncate_scheduledsession; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_scheduledsession BEFORE TRUNCATE ON public."ScheduledSession" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: ScheduledSession block_truncate_session; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_session BEFORE TRUNCATE ON public."ScheduledSession" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: User block_truncate_user; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_user BEFORE TRUNCATE ON public."User" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserAvailability block_truncate_useravailability; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_useravailability BEFORE TRUNCATE ON public."UserAvailability" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserFriends block_truncate_userfriends; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_userfriends BEFORE TRUNCATE ON public."UserFriends" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserGamePreference block_truncate_usergamepreference; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_usergamepreference BEFORE TRUNCATE ON public."UserGamePreference" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserNotifications block_truncate_usernotifications; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_usernotifications BEFORE TRUNCATE ON public."UserNotifications" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserProfile block_truncate_userprofile; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_userprofile BEFORE TRUNCATE ON public."UserProfile" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: UserSession block_truncate_usersession; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER block_truncate_usersession BEFORE TRUNCATE ON public."UserSession" FOR EACH STATEMENT EXECUTE FUNCTION public.block_truncate();


--
-- Name: GameRequest game_request_notify_trigger; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER game_request_notify_trigger AFTER INSERT OR UPDATE ON public."GameRequest" FOR EACH ROW EXECUTE FUNCTION public.notify_game_request_change();


--
-- Name: UserAvailability set_updated_at; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public."UserAvailability" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: UserGamePreference set_updated_at; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public."UserGamePreference" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: UserProfile set_updated_at; Type: TRIGGER; Schema: public; Owner: raz@tovtech.org
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public."UserProfile" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: EmailVerification EmailVerification_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."EmailVerification"
    ADD CONSTRAINT "EmailVerification_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: GameRequest GameRequest_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."GameRequest"
    ADD CONSTRAINT "GameRequest_game_id_fkey" FOREIGN KEY (game_id) REFERENCES public."Game"(id);


--
-- Name: GameRequest GameRequest_recipient_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."GameRequest"
    ADD CONSTRAINT "GameRequest_recipient_user_id_fkey" FOREIGN KEY (recipient_user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: GameRequest GameRequest_sender_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."GameRequest"
    ADD CONSTRAINT "GameRequest_sender_user_id_fkey" FOREIGN KEY (sender_user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: ScheduledSession ScheduledSession_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ScheduledSession"
    ADD CONSTRAINT "ScheduledSession_game_id_fkey" FOREIGN KEY (game_id) REFERENCES public."Game"(id);


--
-- Name: ScheduledSession ScheduledSession_organizer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ScheduledSession"
    ADD CONSTRAINT "ScheduledSession_organizer_user_id_fkey" FOREIGN KEY (organizer_user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: ScheduledSession ScheduledSession_second_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ScheduledSession"
    ADD CONSTRAINT "ScheduledSession_second_player_id_fkey" FOREIGN KEY (second_player_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: ScheduledSession ScheduledSession_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."ScheduledSession"
    ADD CONSTRAINT "ScheduledSession_session_id_fkey" FOREIGN KEY (session_id) REFERENCES public."GameRequest"(id) ON DELETE CASCADE;


--
-- Name: UserAvailability UserAvailability_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserAvailability"
    ADD CONSTRAINT "UserAvailability_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: UserFriends UserFriends_recipient_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserFriends"
    ADD CONSTRAINT "UserFriends_recipient_user_id_fkey" FOREIGN KEY (recipient_user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: UserFriends UserFriends_sender_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserFriends"
    ADD CONSTRAINT "UserFriends_sender_user_id_fkey" FOREIGN KEY (sender_user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: UserGamePreference UserGamePreference_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserGamePreference"
    ADD CONSTRAINT "UserGamePreference_game_id_fkey" FOREIGN KEY (game_id) REFERENCES public."Game"(id);


--
-- Name: UserGamePreference UserGamePreference_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserGamePreference"
    ADD CONSTRAINT "UserGamePreference_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: UserNotifications UserNotifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserNotifications"
    ADD CONSTRAINT "UserNotifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id);


--
-- Name: UserProfile UserProfile_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserProfile"
    ADD CONSTRAINT "UserProfile_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: UserSession UserSession_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public."UserSession"
    ADD CONSTRAINT "UserSession_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."User"(id) ON DELETE CASCADE;


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: raz@tovtech.org
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."User"(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO tovplay_app;
GRANT USAGE ON SCHEMA public TO tovplay_readonly;


--
-- Name: TABLE "BackupLog"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."BackupLog" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."BackupLog" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."BackupLog" TO tovplay_app;
GRANT SELECT ON TABLE public."BackupLog" TO tovplay_readonly;


--
-- Name: SEQUENCE "BackupLog_id_seq"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

GRANT SELECT,USAGE ON SEQUENCE public."BackupLog_id_seq" TO tovplay_app;


--
-- Name: TABLE "ConnectionAuditLog"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."ConnectionAuditLog" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."ConnectionAuditLog" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."ConnectionAuditLog" TO tovplay_app;
GRANT SELECT ON TABLE public."ConnectionAuditLog" TO tovplay_readonly;


--
-- Name: SEQUENCE "ConnectionAuditLog_id_seq"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

GRANT SELECT,USAGE ON SEQUENCE public."ConnectionAuditLog_id_seq" TO tovplay_app;


--
-- Name: TABLE "DeleteAuditLog"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."DeleteAuditLog" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."DeleteAuditLog" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."DeleteAuditLog" TO tovplay_app;
GRANT SELECT ON TABLE public."DeleteAuditLog" TO tovplay_readonly;


--
-- Name: SEQUENCE "DeleteAuditLog_id_seq"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

GRANT SELECT,USAGE ON SEQUENCE public."DeleteAuditLog_id_seq" TO tovplay_app;


--
-- Name: TABLE "EmailVerification"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."EmailVerification" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."EmailVerification" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."EmailVerification" TO tovplay_app;
GRANT SELECT ON TABLE public."EmailVerification" TO tovplay_readonly;


--
-- Name: TABLE "Game"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."Game" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."Game" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Game" TO tovplay_app;
GRANT SELECT ON TABLE public."Game" TO tovplay_readonly;


--
-- Name: TABLE "GameRequest"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."GameRequest" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."GameRequest" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."GameRequest" TO tovplay_app;
GRANT SELECT ON TABLE public."GameRequest" TO tovplay_readonly;


--
-- Name: TABLE "ProtectionStatus"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."ProtectionStatus" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."ProtectionStatus" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."ProtectionStatus" TO tovplay_app;
GRANT SELECT ON TABLE public."ProtectionStatus" TO tovplay_readonly;


--
-- Name: SEQUENCE "ProtectionStatus_id_seq"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

GRANT SELECT,USAGE ON SEQUENCE public."ProtectionStatus_id_seq" TO tovplay_app;


--
-- Name: TABLE "ScheduledSession"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."ScheduledSession" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."ScheduledSession" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."ScheduledSession" TO tovplay_app;
GRANT SELECT ON TABLE public."ScheduledSession" TO tovplay_readonly;


--
-- Name: TABLE "User"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."User" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."User" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."User" TO tovplay_app;
GRANT SELECT ON TABLE public."User" TO tovplay_readonly;


--
-- Name: TABLE "UserAvailability"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."UserAvailability" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."UserAvailability" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."UserAvailability" TO tovplay_app;
GRANT SELECT ON TABLE public."UserAvailability" TO tovplay_readonly;


--
-- Name: TABLE "UserFriends"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."UserFriends" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."UserFriends" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."UserFriends" TO tovplay_app;
GRANT SELECT ON TABLE public."UserFriends" TO tovplay_readonly;


--
-- Name: TABLE "UserGamePreference"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."UserGamePreference" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."UserGamePreference" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."UserGamePreference" TO tovplay_app;
GRANT SELECT ON TABLE public."UserGamePreference" TO tovplay_readonly;


--
-- Name: TABLE "UserNotifications"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."UserNotifications" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."UserNotifications" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."UserNotifications" TO tovplay_app;
GRANT SELECT ON TABLE public."UserNotifications" TO tovplay_readonly;


--
-- Name: TABLE "UserProfile"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."UserProfile" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."UserProfile" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."UserProfile" TO tovplay_app;
GRANT SELECT ON TABLE public."UserProfile" TO tovplay_readonly;


--
-- Name: TABLE "UserSession"; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public."UserSession" FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public."UserSession" TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."UserSession" TO tovplay_app;
GRANT SELECT ON TABLE public."UserSession" TO tovplay_readonly;


--
-- Name: TABLE alembic_version; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public.alembic_version FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public.alembic_version TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.alembic_version TO tovplay_app;
GRANT SELECT ON TABLE public.alembic_version TO tovplay_readonly;


--
-- Name: TABLE auditlog; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public.auditlog FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public.auditlog TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.auditlog TO tovplay_app;
GRANT SELECT ON TABLE public.auditlog TO tovplay_readonly;


--
-- Name: SEQUENCE auditlog_id_seq; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

GRANT SELECT,USAGE ON SEQUENCE public.auditlog_id_seq TO tovplay_app;


--
-- Name: TABLE password_reset_tokens; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

REVOKE ALL ON TABLE public.password_reset_tokens FROM "raz@tovtech.org";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,MAINTAIN,UPDATE ON TABLE public.password_reset_tokens TO "raz@tovtech.org";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.password_reset_tokens TO tovplay_app;
GRANT SELECT ON TABLE public.password_reset_tokens TO tovplay_readonly;


--
-- Name: SEQUENCE password_reset_tokens_id_seq; Type: ACL; Schema: public; Owner: raz@tovtech.org
--

GRANT SELECT,USAGE ON SEQUENCE public.password_reset_tokens_id_seq TO tovplay_app;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: raz@tovtech.org
--

ALTER DEFAULT PRIVILEGES FOR ROLE "raz@tovtech.org" IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO tovplay_app;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: raz@tovtech.org
--

ALTER DEFAULT PRIVILEGES FOR ROLE "raz@tovtech.org" IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO tovplay_app;
ALTER DEFAULT PRIVILEGES FOR ROLE "raz@tovtech.org" IN SCHEMA public GRANT SELECT ON TABLES TO tovplay_readonly;


--
-- PostgreSQL database dump complete
--

\unrestrict MQpybRA58RRBkOrY5MH4ONgUqde74qoe4YDHcwDUUDJRukvpbYwRUC4Fvb48WFX

