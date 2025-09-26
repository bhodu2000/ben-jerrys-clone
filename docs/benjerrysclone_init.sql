/* ============================================================
   Ben & Jerry's – Full Schema + Seed
   ============================================================ */

DROP DATABASE IF EXISTS benjerrysclone;
CREATE DATABASE benjerrysclone
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE benjerrysclone;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ======================
-- Drop 기존 트리거/테이블
-- ======================
DROP TRIGGER IF EXISTS trg_vm_bi;
DROP TRIGGER IF EXISTS trg_vm_bu;
DROP TRIGGER IF EXISTS trg_variant_bu_active;
DROP TRIGGER IF EXISTS trg_reco_bi;
DROP TRIGGER IF EXISTS trg_reco_bu;
DROP TRIGGER IF EXISTS trg_flavour_bi;
DROP TRIGGER IF EXISTS trg_flavour_bu;

DROP PROCEDURE IF EXISTS promote_latest_cohort;

DROP TABLE IF EXISTS variant_reco;
DROP TABLE IF EXISTS variant_relation;
DROP TABLE IF EXISTS flavour_tag;
DROP TABLE IF EXISTS tag_alias;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS variant_cert;
DROP TABLE IF EXISTS dietary_cert;
DROP TABLE IF EXISTS variant_sourcing;
DROP TABLE IF EXISTS sourcing_feature;
DROP TABLE IF EXISTS variant_ingredients;
DROP TABLE IF EXISTS variant_media;
DROP TABLE IF EXISTS product_variant;
DROP TABLE IF EXISTS article;
DROP TABLE IF EXISTS flavour;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS flavour_type;

/* ======================
   Base master tables
   ====================== */

CREATE TABLE category (
  id                  BIGINT PRIMARY KEY AUTO_INCREMENT,
  code                VARCHAR(30)  NOT NULL UNIQUE,
  slug                VARCHAR(30) NOT NULL UNIQUE,
  list_slug           VARCHAR(30) NOT NULL UNIQUE,
  name_ko             VARCHAR(30) NOT NULL,
  priority            INT NOT NULL DEFAULT 100,
  packshot_basename   VARCHAR(50) NOT NULL DEFAULT 'main',
  nutrition_basename  VARCHAR(50) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE flavour_type (
  id            TINYINT PRIMARY KEY,
  code          VARCHAR(30) NOT NULL UNIQUE,
  name_ko       VARCHAR(30) NOT NULL,
  sort_priority TINYINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE flavour (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  slug            VARCHAR(150) NOT NULL UNIQUE,
  name_ko         VARCHAR(100) NOT NULL,
  description_ko  TEXT,
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  is_new          TINYINT(1)   NOT NULL DEFAULT 0,
  flavour_type_id TINYINT      NOT NULL DEFAULT 1,
  flavour_sort_rank TINYINT    NOT NULL DEFAULT 9,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_flavour_type
    FOREIGN KEY (flavour_type_id) REFERENCES flavour_type(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  INDEX idx_flavour_list       (is_active, flavour_sort_rank, name_ko),
  INDEX idx_flavour_created_at (created_at),
  INDEX idx_flavour_is_new     (is_new)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE product_variant (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  flavour_id    BIGINT NOT NULL,
  category_id   BIGINT NOT NULL,
  variant_description_ko TEXT,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  sort_order    INT NULL COMMENT 'NULL=기본정렬, 값 있으면 그룹 내 수동 오버라이드',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  UNIQUE KEY uq_variant (flavour_id, category_id),
  INDEX idx_variant_active_category (is_active, category_id),
  CONSTRAINT fk_variant_flavour
    FOREIGN KEY (flavour_id) REFERENCES flavour(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT fk_variant_category
    FOREIGN KEY (category_id) REFERENCES category(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/* ======================
   Variant media (하이브리드 정렬)
   ====================== */

CREATE TABLE variant_media (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  variant_id   BIGINT NOT NULL,
  role         ENUM('PACKSHOT','GALLERY','NUTRITION') NOT NULL DEFAULT 'GALLERY',
  url          VARCHAR(300) NOT NULL,
  alt_ko       VARCHAR(150),
  sort_order   INT NOT NULL DEFAULT 0,

  file_basename       VARCHAR(255)
    GENERATED ALWAYS AS (SUBSTRING_INDEX(url, '/', -1)) STORED,
  gallery_num_prefix  INT
    GENERATED ALWAYS AS (
      CAST(REGEXP_SUBSTR(SUBSTRING_INDEX(url, '/', -1), '^[0-9]+') AS UNSIGNED)
    ) STORED,

  CONSTRAINT chk_vm_gallery_prefix_relaxed
    CHECK (
      role <> 'GALLERY'
      OR (
        (gallery_num_prefix BETWEEN 1 AND 99)
        OR (sort_order BETWEEN 1 AND 99)
      )
    ),

  UNIQUE KEY uq_vm_nodup (variant_id, role, url),
  INDEX idx_vm_variant (variant_id, role, sort_order),
  INDEX idx_vm_variant_id (variant_id),

  UNIQUE KEY uq_vm_single_role_expr (
    (CASE
       WHEN role IN ('PACKSHOT','NUTRITION') THEN CONCAT(variant_id,'#',role)
       ELSE NULL
     END)
  ),

  UNIQUE KEY uq_vm_gallery_order_expr (
    (CASE
       WHEN role='GALLERY' THEN CONCAT(variant_id,'#',LPAD(sort_order,2,'0'))
       ELSE NULL
     END)
  ),

  CONSTRAINT fk_variant_media__product_variant
    FOREIGN KEY (variant_id) REFERENCES product_variant(id)
    ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ======================
-- Variant ingredients (영양 이미지는 variant_media.NUTRITION 사용)
-- ======================

CREATE TABLE variant_ingredients (
  id               BIGINT PRIMARY KEY AUTO_INCREMENT,
  variant_id       BIGINT NOT NULL,
  ingredients_ko   MEDIUMTEXT,                    -- HTML/문단 허용
  smartlabel_url   VARCHAR(300),

  UNIQUE KEY uq_vi_variant (variant_id),
  CONSTRAINT fk_vi_variant
    FOREIGN KEY (variant_id) REFERENCES product_variant(id)
    ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ======================
-- Values-led sourcing (badges)
-- ======================

CREATE TABLE sourcing_feature (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  code       VARCHAR(50)  NOT NULL UNIQUE,        -- NON_GMO, FAIRTRADE ...
  name_ko    VARCHAR(100) NOT NULL,
  icon_url   VARCHAR(300) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE variant_sourcing (
  variant_id BIGINT NOT NULL,
  feature_id BIGINT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,

  PRIMARY KEY (variant_id, feature_id),
  INDEX idx_vs_variant (variant_id, sort_order),
  CONSTRAINT fk_vs_variant
    FOREIGN KEY (variant_id) REFERENCES product_variant(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT fk_vs_feature
    FOREIGN KEY (feature_id) REFERENCES sourcing_feature(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ======================
-- Dietary Certifications (badges)
-- ======================

CREATE TABLE dietary_cert (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  code       VARCHAR(50)  NOT NULL UNIQUE,        -- KOSHER_DAIRY, GLUTEN_FREE ...
  name_ko    VARCHAR(100) NOT NULL,
  icon_url   VARCHAR(300) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE variant_cert (
  variant_id BIGINT NOT NULL,
  cert_id    BIGINT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,

  PRIMARY KEY (variant_id, cert_id),
  INDEX idx_vc_variant (variant_id, sort_order),
  CONSTRAINT fk_vc_variant
    FOREIGN KEY (variant_id) REFERENCES product_variant(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT fk_vc_cert
    FOREIGN KEY (cert_id) REFERENCES dietary_cert(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ======================
-- Tags + Alias
-- ======================

CREATE TABLE tag (
  id       BIGINT PRIMARY KEY AUTO_INCREMENT,
  slug     VARCHAR(100) NOT NULL UNIQUE,
  name_ko  VARCHAR(100) NOT NULL,
  INDEX idx_tag_name (name_ko)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tag_alias (
  tag_id BIGINT NOT NULL,
  alias  VARCHAR(100) NOT NULL,                    -- 예: 초코, choco
  PRIMARY KEY (tag_id, alias),
  UNIQUE KEY uq_alias (alias),
  INDEX idx_alias (alias),
  CONSTRAINT fk_alias_tag
    FOREIGN KEY (tag_id) REFERENCES tag(id)
    ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE flavour_tag (
  flavour_id BIGINT NOT NULL,
  tag_id     BIGINT NOT NULL,
  PRIMARY KEY (flavour_id, tag_id),
  INDEX idx_ft_tag (tag_id),
  CONSTRAINT fk_ft_flavour
    FOREIGN KEY (flavour_id) REFERENCES flavour(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT fk_ft_tag
    FOREIGN KEY (tag_id) REFERENCES tag(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ======================
-- Article (whats-new)
-- ======================

CREATE TABLE article (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  slug         VARCHAR(150) NOT NULL UNIQUE,       -- free-cone-day-flavor
  title_ko     VARCHAR(150) NOT NULL,
  excerpt_ko   TEXT,
  content_ko   LONGTEXT,
  is_active    TINYINT(1) NOT NULL DEFAULT 1,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
  published_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_article_active_created (is_active, created_at),
  INDEX idx_article_published (is_active, published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ======================
-- Recommendations (같은 카테고리의 다른 3가지 맛)
-- ======================

CREATE TABLE variant_reco (
  source_variant_id  BIGINT NOT NULL,
  target_variant_id  BIGINT NOT NULL,
  slot               TINYINT NOT NULL,          -- 1,2,3

  CONSTRAINT pk_reco_slot PRIMARY KEY (source_variant_id, slot),
  CONSTRAINT uq_reco_target UNIQUE (source_variant_id, target_variant_id),
  CONSTRAINT chk_reco_slot CHECK (slot BETWEEN 1 AND 3),
  CONSTRAINT chk_reco_self CHECK (source_variant_id <> target_variant_id),

  CONSTRAINT fk_reco_source FOREIGN KEY (source_variant_id)
    REFERENCES product_variant(id) ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT fk_reco_target FOREIGN KEY (target_variant_id)
    REFERENCES product_variant(id) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


/* ======================
   Triggers & Procedures
   ====================== */
DELIMITER $$

DROP TRIGGER IF EXISTS trg_flavour_bi $$
CREATE TRIGGER trg_flavour_bi
BEFORE INSERT ON flavour
FOR EACH ROW
BEGIN
  DECLARE v_original_id TINYINT;
  DECLARE v_core_id     TINYINT;
  DECLARE v_sorbet_id   TINYINT;
  DECLARE v_pri         TINYINT;

  SELECT id INTO v_original_id FROM flavour_type WHERE code='ORIGINAL' LIMIT 1;
  IF v_original_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='flavour_type ORIGINAL is missing';
  END IF;
  SELECT id INTO v_core_id   FROM flavour_type WHERE code='CORE'   LIMIT 1;
  SELECT id INTO v_sorbet_id FROM flavour_type WHERE code='SORBET' LIMIT 1;

  -- 기본은 항상 ORIGINAL
  SET NEW.flavour_type_id = v_original_id;

  -- slug 접미사 규칙 오버라이드
  IF NEW.slug LIKE '%-core' THEN
    IF v_core_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='flavour_type CORE is missing for -core slug';
    END IF;
    SET NEW.flavour_type_id = v_core_id;

  ELSEIF NEW.slug LIKE '%-sorbet' THEN
    IF v_sorbet_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='flavour_type SORBET is missing for -sorbet slug';
    END IF;
    SET NEW.flavour_type_id = v_sorbet_id;
  END IF;

  SELECT sort_priority INTO v_pri
    FROM flavour_type WHERE id = NEW.flavour_type_id LIMIT 1;

  SET NEW.flavour_sort_rank =
    CASE WHEN NEW.is_new=1 THEN 0 ELSE COALESCE(v_pri,9) END;
END$$


DROP TRIGGER IF EXISTS trg_flavour_bu $$
CREATE TRIGGER trg_flavour_bu
BEFORE UPDATE ON flavour
FOR EACH ROW
BEGIN
  DECLARE v_original_id TINYINT;
  DECLARE v_core_id     TINYINT;
  DECLARE v_sorbet_id   TINYINT;
  DECLARE v_pri         TINYINT;

  SELECT id INTO v_original_id FROM flavour_type WHERE code='ORIGINAL' LIMIT 1;
  IF v_original_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='flavour_type ORIGINAL is missing';
  END IF;
  SELECT id INTO v_core_id   FROM flavour_type WHERE code='CORE'   LIMIT 1;
  SELECT id INTO v_sorbet_id FROM flavour_type WHERE code='SORBET' LIMIT 1;

  SET NEW.flavour_type_id = v_original_id;

  IF NEW.slug LIKE '%-core' THEN
    IF v_core_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='flavour_type CORE is missing for -core slug';
    END IF;
    SET NEW.flavour_type_id = v_core_id;

  ELSEIF NEW.slug LIKE '%-sorbet' THEN
    IF v_sorbet_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='flavour_type SORBET is missing for -sorbet slug';
    END IF;
    SET NEW.flavour_type_id = v_sorbet_id;
  END IF;

  SELECT sort_priority INTO v_pri
    FROM flavour_type WHERE id = NEW.flavour_type_id LIMIT 1;

  SET NEW.flavour_sort_rank =
    CASE WHEN NEW.is_new=1 THEN 0 ELSE COALESCE(v_pri,9) END;
END$$

-- variant_media BEFORE INSERT
DROP TRIGGER IF EXISTS trg_vm_bi $$
CREATE TRIGGER trg_vm_bi
BEFORE INSERT ON variant_media
FOR EACH ROW
BEGIN
  IF NEW.role = 'GALLERY' THEN
    SET NEW.sort_order = COALESCE(NULLIF(NEW.sort_order,0), NEW.gallery_num_prefix);
  ELSEIF NEW.role IN ('PACKSHOT','NUTRITION') THEN
    SET NEW.sort_order = 0;
  END IF;
END$$

-- variant_media BEFORE UPDATE
DROP TRIGGER IF EXISTS trg_vm_bu $$
CREATE TRIGGER trg_vm_bu
BEFORE UPDATE ON variant_media
FOR EACH ROW
BEGIN
  IF NEW.role = 'GALLERY' THEN
    SET NEW.sort_order = COALESCE(NULLIF(NEW.sort_order,0), NEW.gallery_num_prefix);
  ELSEIF NEW.role IN ('PACKSHOT','NUTRITION') THEN
    SET NEW.sort_order = 0;
  END IF;
END$$


-- 최신 코호트 승격 프로시저
CREATE PROCEDURE promote_latest_cohort()
proc: BEGIN
  DECLARE v_max DATETIME(6);
  START TRANSACTION;
  SELECT MAX(created_at) INTO v_max FROM flavour;
  IF v_max IS NULL THEN
    COMMIT;
    LEAVE proc;
  END IF;
  UPDATE flavour f
     SET f.is_new = 0,
         f.flavour_sort_rank = COALESCE((
           SELECT ft.sort_priority FROM flavour_type ft
            WHERE ft.id = f.flavour_type_id LIMIT 1
         ), 9)
   WHERE f.is_new = 1;
  UPDATE flavour f
     SET f.is_new = 1,
         f.flavour_sort_rank = 0
   WHERE f.created_at = v_max;
  COMMIT;
END $$
DELIMITER ;



/* ============================================
    seed data
   ============================================ */

SET NAMES utf8mb4;

-- 0) Category
INSERT INTO category (id, code, slug, list_slug, name_ko, priority, packshot_basename, nutrition_basename) VALUES
  (10001,'PINT','pint','ice-cream-pints','파인트',1,'main','473ml'),
  (10002,'MINI_CUP','mini-cup','ice-cream-cups','미니컵',2,'main','120ml'),
  (10003,'SCOOP','scoop-shop','ice-cream-shop-flavours','스쿱 샵',3,'main',NULL)
ON DUPLICATE KEY UPDATE name_ko=VALUES(name_ko), priority=VALUES(priority),
  packshot_basename=VALUES(packshot_basename), nutrition_basename=VALUES(nutrition_basename);

-- 1) Flavour types
INSERT INTO flavour_type (id, code, name_ko, sort_priority) VALUES
  (1, 'ORIGINAL', '오리지널 아이스크림', 1),
  (2, 'CORE',     '코어', 2),
  (3, 'SORBET',   '소르베(셔벗)', 3)
ON DUPLICATE KEY UPDATE name_ko=VALUES(name_ko), sort_priority=VALUES(sort_priority);

-- 2) Values-led features
INSERT INTO sourcing_feature (id, code, name_ko, icon_url) VALUES
  (90001,'NON_GMO','Non-GMO','/assets/img/misc/90001_Non-GMO_VLS_Simpler_Icons.avif'),
  (90002,'CAGE_FREE_EGGS','Cage-Free Eggs','/assets/img/misc/90002_Cage-free_Eggs_VLS_Simpler_Icons.webp'),
  (90003,'FREE_RANGE_EGGS','Free Range Eggs','/assets/img/misc/90003_Free-range_Eggs_VLS_Simpler_Icons.webp'),
  (90004,'FAIRTRADE','Fairtrade','/assets/img/misc/90004_Fairtrade_VLS_Simpler_Icons.avif'),
  (90005,'CARING_DAIRY','Caring Dairy','/assets/img/misc/90005_Caring_Dairy_VLS_Simpler_Icons.avif'),
  (90006,'RESPONSIBLY_SOURCED_PACKAGING','Responsibly Sourced Packaging','/assets/img/misc/90006_Responsibly_Sourced_Packaging_VLS_Simpler_Icons.avif'),
  (90007,'GREYSTON_BROWNIES','Greyston Brownies','/assets/img/misc/90007_Greyston_Brownies_VLS_Simpler_Icons.png'),
  (90008,'OPEN_CHAIN_SOURCING','Open Chain Sourcing','/assets/img/misc/90008_Cocoa_Sourcing_VLS_Simpler_Icons.avif')
ON DUPLICATE KEY UPDATE name_ko=VALUES(name_ko), icon_url=VALUES(icon_url);

-- 3) Dietary certifications
INSERT INTO dietary_cert (id, code, name_ko, icon_url) VALUES
  (91001,'HALAL','Halal', '/assets/img/misc/91001_Halal_Dietary_Icon.avif'),
  (91002,'KOSHER_DAIRY','Kosher Dairy','/assets/img/misc/91002_Kosher_Dairy_Dietary_Icon.png'),
  (91003,'GLUTEN_FREE','Gluten Free','/assets/img/misc/91003_Gluten-free_Dietary_Icon.png')
ON DUPLICATE KEY UPDATE name_ko=VALUES(name_ko), icon_url=VALUES(icon_url);

-- 4) Flavours (All)
INSERT INTO flavour (id, slug, name_ko, description_ko, is_active, is_new) VALUES
  (20001,'chunky-monkey-ice-cream','청키 몽키®','호두 퍼지 덩어리가 들어간 바나나 아이스크림',1,0),
  (20002,'half-baked-ice-cream','하프베이크드®','초코칩 쿠키도우와 퍼지 브라우니의 청크가 절묘하게 어우러진 초콜릿 & 바닐라 아이스크림',1,0),
  (20003,'chocolate-fudge-brownie-ice-cream','초콜릿 퍼지 브라우니','퍼지 브라우니가 들어간 초콜릿 아이스크림',1,0),
  (20004,'strawberry-cheesecake-ice-cream','스트로베리 치즈케이크','그라함 크래커 스월이 가득한 스트로베리 치즈케이크 아이스크림',1,1),
  (20005,'chocolate-chip-cookie-dough-ice-cream','초콜릿 칩 쿠키 도우','초콜릿 칩 쿠키 도우의 퍼지 덩어리가 들어간 바닐라 아이스크림',1,0),
  (20006,'cherry-garcia-ice-cream','체리 가르시아®','체리 퍼지 플레이크가 들어간 체리 아이스크림',1,0),
  (20007,'coffee-coffee-buzz-buzz-buzz-ice-cream','커피커피 버즈버즈버즈!','커피 아이스크림 베이스에 에스프레소 빈 퍼지가 들어있는 아이스크림',1,0),
  (20008,'karamel-sutra-core','카라멜 수트라','퍼지 칩과 부드러운 카라멜이 들어있는 초콜릿 & 카라멜 아이스크림',1,0),
  (20009,'mint-chocolate-cookie-ice-cream','민트 초콜릿 칩 쿠키','신선한 민트 아이스크림 베이스에 초콜릿 쿠키가 덩어리 채 들어있는 아이스크림',1,0),
  (20010,'new-york-super-fudge-chunk-ice-cream','뉴욕 수퍼 퍼지 청크','화이트 & 다크 퍼지 청크, 피칸, 호두, 아몬드가 들어있는 초콜릿 아이스크림',1,0),
  (20011,'peanut-butter-cup-ice-cream','피넛 버터 컵','고소한 피넛버터 아이스크림에 피넛버터 초콜릿이 콕콕 박혀있는 아이스크림',1,0),
  (20012,'pistachio-pistachio-ice-cream','피스타치오 피스타치오','가볍게 로스팅한 피스타치오가 들어있는 피스타치오 아이스크림',1,0),
  (20013,'vanilla-ice-cream','바닐라','바닐라 아이스크림',1,0),
  (20014,'chocolate-ice-cream','초콜릿','초콜릿 아이스크림',1,1),
  (20015,'lemonade-sorbet','레모네이드 소르베','상큼한 레모네이드 맛의 소르베',1,0),
  (20016,'mint-chocolate-chunk-ice-cream','민트 초콜릿 청크','민트 아이스크림 베이스에 초콜릿 칩이 덩어리 채 들어있는 아이스크림',1,0),
  (20017,'strawberry-ice-cream','스트로베리','딸기 아이스크림 베이스에 딸기 과육이 듬뿍 들어있는 아이스크림',1,0),
  (20018,'berry-berry-extraordinary-sorbet','베리베리 엑스트라 오디너리®','블루베리와 라즈베리 등 각종 베리류가 듬뿍 들어있는 소르베',1,0),
  (20019,'sweet-cream-and-cookies-ice-cream','스위트 크림&쿠키','바닐라 아이스크림 베이스에 초코 쿠키와 스위트 크림이 듬뿍 들어있는 아이스크림',1,0)
ON DUPLICATE KEY UPDATE name_ko=VALUES(name_ko), description_ko=VALUES(description_ko);

-- (보정) slug 규칙 백필
UPDATE flavour f
JOIN flavour_type t ON t.code='CORE'
SET f.flavour_type_id = t.id
WHERE f.slug LIKE '%-core';
UPDATE flavour f
JOIN flavour_type t ON t.code='SORBET'
SET f.flavour_type_id = t.id
WHERE f.slug LIKE '%-sorbet';


-- 5) Product variants (All)
INSERT INTO product_variant (id, flavour_id, category_id, variant_description_ko, is_active, sort_order) VALUES
  -- PINT 13개
  (30001,20001,10001,'이름만큼 재미있는 맛을 내기 위해 최종적으로 맛을 결정할 때까지 여러 개의 테스트 배치를 가지고 놀았습니다. 원숭이가 먹을 바나나는 없지만 견과류와 초콜릿 덩어리가 가득 들어있습니다.',1,NULL),
  (30002,20002,10001,'우리는 스쿱샵에 들릴 때 마다 우리의 친구들이 가장 맛있을 법한 새롭고 쿨한 콤보를 만들기 위해 다양한 맛의 조합을 시도하는 것을 알게 되었습니다. 그때 우리는 이것이 정말 엄청난 아이디어라고 생각 했어요. 그래서 우리는 여러분이 사랑하는 벤앤제리스의 맛과 절묘하게 어우러진 새로운 맛을 찾기 위해 여러분이 새롭게 조합한 맛을 함께 섞어 보았습니다. 여러분은 우리가 엉뚱하다고 말할지도 모르겠지만, 우리는 말할 수 있어요. 이건 하프 베이크드 라고 해! Enjoy! 벤앤제리스를 사랑하는 모든 이들에게 감사해요.',1,NULL),
  (30003,20003,10001,'풍부한 맛을 지닌 다크 초콜릿에 브라우니 퍼지 덩어리를 절묘하게 배합한 아이스크림입니다. 꿈꿔왔던 그 맛.',1,NULL),
  (30004,20004,10001,'항상 치즈케이크를 먹고 싶어하는 애호가들을 위해 딸기 과육이 가득하고, 부드러운 치즈케이크의 풍미와 환상적인 그라함 크래커 스월이 가득 찬 아이스크림 입니다.',1,NULL),
  (30005,20005,10001,'크리미 바닐라 아이스크림이 커다란 초콜릿 칩 쿠키 도우 덩어리를 부드럽게 감싸며 조화를 이룹니다. 요즘은 그렇게 생각하지 않지만, 1984년에는 혁명적인 맛이었습니다.',1,NULL),
  (30006,20006,10001,'전세계 기타리스트 제리 가르시아와 그레이트풀 데드 팬들에게 바치는 먹을 수 있는 최고의 찬사를 보내며, 팬들이 제안한 맛으로 가장 유명한 전설적인 락 밴드의 이름을 따서 만든 최초의 아이스크림입니다.',1,NULL),
  (30007,20007,10001,'당신의 정신을 번쩍 들게 할, 그리고 곧 사랑을 빠져 노래를 흥얼거리게 만드는 맛! 크리미한 커피 맛 아이스크림에 에스프레소 퍼지가 가득!',1,NULL),
  (30008,20008,10001,'벤앤제리스 Core를 통해 최고의 아이스크림을 경험해보세요. 원초적인 충동이 카라멜 수트라의 중심에 있는 부드러운 카라멜로 이끌든 퍼지 칩으로 이끌든, 당신은 카라멜 수트라 맛에 빠져들거에요. 글루텐 프리 제품.',1,NULL),
  (30009,20009,10001,'신선한 민트 아이스크림 베이스에 초콜릿 쿠키가 덩어리 채 들어있는 아이스크림.인공색소가 들어가지 않은 하얀색 민트 아이스크림과 초콜릿이 선사하는 색다른 달콤함을 즐겨보세요!',1,NULL),
  (30010,20010,10001,'1985년에 벤앤제리스는 뉴욕만의 새로운 플레이버로 다양한 종류의 청크들을 넣은 뉴욕 수퍼 퍼지 청크를 탄생시켰습니다. 뉴욕에서도 인기있는 플레이버라면 어디서든 맛 볼 수 있을거라 생각했어요. 실제로도 그렇고요.',1,NULL),
  (30011,20011,10001,'고소한 피넛(땅콩) 버터 아이스크림에 달콤하고 짭조름한 피넛(땅콩) 버터 초콜릿이 콕콕 박혀있는 아이스크림.',1,NULL),
  (30012,20012,10001,'이름만으로도 우리가 피스타치오를 얼마나 사랑하는지 알 수 있습니다. 하지만 우리의 말을 그대로 받아들이지 말고, 맛 자체를 말하도록 하세요!',1,NULL),
  (30013,20013,10001,'이 파인트를 더 먹어보면 풍부한 맛의 크림같은 바닐라를 느낄 수 있습니다. 지금까지 맛본 어떤 바닐라보다 더 맛있는 바닐라 맛을 즐겨보세요.',1,NULL),

  -- MINI_CUP 3개
  (30021,20003,10002,'풍부한 맛을 지닌 다크 초콜릿에 브라우니 퍼지 덩어리를 절묘하게 배합한 아이스크림입니다. 꿈꿔왔던 그 맛.',1,NULL),
  (30022,20005,10002,'크리미 바닐라 아이스크림이 커다란 초콜릿 칩 쿠키 도우 덩어리를 부드럽게 감싸며 조화를 이룹니다. 요즘은 그렇게 생각하지 않지만, 1984년에는 혁명적인 맛이었습니다.',1,NULL),
  (30023,20006,10002,'기타리스트인 제리 가르시아 (Jerry Garcia)와 그레이트 풀 데드 (Grateful Dead) 팬들에게 헌사하는 벤앤제리스의 대표 메뉴. 록 전설의 이름을 딴 최초의 아이스크림이자 벤앤제리스의 팬들이 추천하는 가장 유명한 맛입니다.',1,NULL),

  -- SCOOP 13개
  (30031,20006,10003,'전세계 기타리스트 제리 가르시아와 그레이트풀 데드 팬들에게 바치는 먹을 수 있는 최고의 찬사.',1,NULL),
  (30032,20014,10003,'저희 초콜릿 아이스크림은 공정무역 인증® 코코아에서 초콜릿 맛을 얻습니다. 공정무역은 코코아 재배자들이 그들의 수확에 대한 공정한 가격을 보장하고, 그들이 그들의 땅과 생계를 보호하고, 그들의 가족을 위해 제공하고, 그들의 미래에 투자할 수 있도록 합니다. 즐기세요!',1,NULL),
  (30033,20005,10003,'크리미 바닐라 아이스크림이 커다란 초콜릿 칩 쿠키 도우 덩어리를 부드럽게 감싸며 조화를 이룹니다. 요즘은 그렇게 생각하지 않지만, 1984년에는 혁명적인 맛이었습니다.',1,NULL),
  (30034,20003,10003,'초콜릿 퍼지 브라우니 퍼지 브라우니가 들어간 초콜릿 아이스크림 초콜릿 아이스크림에 쫀득한 브라우니가 가득! 사회적 약자들에게 직업교육과 일자리 창출에 힘쓰고 있는 뉴욕의 Greyston Bakery 에서 구워진 벤앤제리스 브라우니가 가득 들어있습니다. 당신의 선택이 그들에게 따뜻한 도움의 손길이 될 수 있다는 걸 잊지 마세요!',1,NULL),
  (30035,20001,10003,'원숭이만 바나나에 반하나? 벤앤제리스도 바나나에 반했다! 고소한 넛츠와 달콤한 초콜릿, 그리고 바나나 아이스크림이 이루는 환상적인 조화! 벤앤제리스에서만 느낄 수 있는 특별한 맛을 지금 맛보세요!',1,NULL),
  (30036,20002,10003,'미국의 그레이스톤 베이커리의 브라우니와 라이노 베이커리의 쿠키도우의 만남! B Corps 인증을 받은 두 회사가 협력하여 만들어진 플레이버, 하프 베이크드. 한 스쿱으로 더 나은 세상을 위한 특별한 맛의 아이스크림 입니다',1,NULL),
  (30037,20015,10003,'이보다 더 상큼할 수 없다! 상큼함과 시원함을 동시에 느껴보세요. 입안에서 살살 녹는 그 상큼한 맛, 궁금하지 않으세요?',1,NULL),
  (30038,20016,10003,'민트 초코 덕후들은 주목! 벤앤제리스 아이스크림 맛의 비결이 무엇일까요? 벤앤제리스는 성장호르몬을 맞지 않은 친환경적인 젖소들을 사랑합니다. 그들이 만들어낸 우유로 만든 아이스크림과 민트, 그리고 덩어리 채 들어있는 초콜릿 칩이 기대되지 않나요?',1,NULL),
  (30039,20010,10003,'오늘부턴 나도 뉴요커! 고소한 아몬드, 호두와 풍부한 초콜릿의 맛이 당신에게 잊을 수 없는 순간을 선물합니다. 뉴욕의 풍부하고 깊은 맛을 사랑하는 사람과 함께 즐겨보세요!',1,NULL),
  (30040,20017,10003,'딸기에 퐁당! 상큼한 딸기 맛 볼 준비되었나요? 벤앤제리스는 성장호르몬을 맞지 않은 친환경적인 젖소를 사랑합니다. 부드럽고 신선한 우유와 풍부한 딸기 청크가 가득한 신선한 맛의 벤앤제리스를 즐겨보세요!',1,NULL),
  (30041,20013,10003,'홈메이드 보다 더 부드러운, 바닐라 아이스크림! 벤앤제리스의 바닐라 빈이 소규모 농부들에 의해 키워진다는 것을 아시나요? 당신의 현명한 선택이 소작농과 농업 사회에 긍정적인 변화의 씨앗이 될 수 있습니다!',1,NULL),
  (30042,20018,10003,'벤앤제리스만의 특별한 베리 맛, 흔하게 맛 볼 수 없는 기쁨의 맛! 상큼한 베리의 조합은 당신이 생각한 무엇보다도 놀라울 거예요',1,NULL),
  (30043,20019,10003,'농장에서 신선한 우유와 크림, 그리고 벤앤제리스가 선택한 스페셜한 청크를 함께 맛보세요! 당신의 하루가 달콤하게 변할거예요',1,NULL);

-- 6) Variant media
-- PACKSHOT (각 variant당 1장)
INSERT INTO variant_media (id, variant_id, role, url, alt_ko, sort_order) VALUES
  (40001,30001,'PACKSHOT','/assets/img/flavours/chunky-monkey-ice-cream/pint/packshot/main.png','청키 몽키 파인트 팩샷',0),
  (40002,30002,'PACKSHOT','/assets/img/flavours/half-baked-ice-cream/pint/packshot/main.png','하프베이크드 파인트 팩샷',0),
  (40003,30003,'PACKSHOT','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/packshot/main.png','초콜릿 퍼지 브라우니 파인트 팩샷',0),
  (40004,30004,'PACKSHOT','/assets/img/flavours/strawberry-cheesecake-ice-cream/pint/packshot/main.png','스트로베리 치즈케이크 파인트 팩샷',0),
  (40005,30005,'PACKSHOT','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/pint/packshot/main.png','초콜릿 칩 쿠키 도우 파인트 팩샷',0),
  (40006,30006,'PACKSHOT','/assets/img/flavours/cherry-garcia-ice-cream/pint/packshot/main.png','체리 가르시아 파인트 팩샷',0),
  (40007,30007,'PACKSHOT','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/packshot/main.png','커피커피 버즈버즈버즈 파인트 팩샷',0),
  (40008,30008,'PACKSHOT','/assets/img/flavours/karamel-sutra-core/pint/packshot/main.png','카라멜 수트라 코어 파인트 팩샷',0),
  (40009,30009,'PACKSHOT','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/packshot/main.png','민트 초콜릿 칩 쿠키 파인트 팩샷',0),
  (40010,30010,'PACKSHOT','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/packshot/main.png','뉴욕 수퍼 퍼지 청크 파인트 팩샷',0),
  (40011,30011,'PACKSHOT','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/packshot/main.png','피넛 버터 컵 파인트 팩샷',0),
  (40012,30012,'PACKSHOT','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/packshot/main.png','피스타치오 파인트 팩샷',0),
  (40013,30013,'PACKSHOT','/assets/img/flavours/vanilla-ice-cream/pint/packshot/main.png','바닐라 파인트 팩샷',0),

  (40021,30021,'PACKSHOT','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/mini-cup/packshot/main.png','초콜릿 퍼지 브라우니 미니컵 팩샷',0),
  (40022,30022,'PACKSHOT','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/mini-cup/packshot/main.png','초콜릿 칩 쿠키 도우 미니컵 팩샷',0),
  (40023,30023,'PACKSHOT','/assets/img/flavours/cherry-garcia-ice-cream/mini-cup/packshot/main.png','체리 가르시아 미니컵 팩샷',0),

  (40031,30031,'PACKSHOT','/assets/img/flavours/cherry-garcia-ice-cream/scoop-shop/packshot/main.png','체리 가르시아 스쿱 팩샷',0),
  (40032,30032,'PACKSHOT','/assets/img/flavours/chocolate-ice-cream/scoop-shop/packshot/main.png','초콜릿 스쿱 팩샷',0),
  (40033,30033,'PACKSHOT','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/scoop-shop/packshot/main.png','초콜릿 칩 쿠키 도우 스쿱 팩샷',0),
  (40034,30034,'PACKSHOT','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/scoop-shop/packshot/main.png','초콜릿 퍼지 브라우니 스쿱 팩샷',0),
  (40035,30035,'PACKSHOT','/assets/img/flavours/chunky-monkey-ice-cream/scoop-shop/packshot/main.png','청키 몽키 스쿱 팩샷',0),
  (40036,30036,'PACKSHOT','/assets/img/flavours/half-baked-ice-cream/scoop-shop/packshot/main.png','하프베이크드 스쿱 팩샷',0),
  (40037,30037,'PACKSHOT','/assets/img/flavours/lemonade-sorbet/scoop-shop/packshot/main.png','레모네이드 소르베 스쿱 팩샷',0),
  (40038,30038,'PACKSHOT','/assets/img/flavours/mint-chocolate-chunk-ice-cream/scoop-shop/packshot/main.png','민트 초콜릿 청크 스쿱 팩샷',0),
  (40039,30039,'PACKSHOT','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/scoop-shop/packshot/main.png','뉴욕 수퍼 퍼지 청크 스쿱 팩샷',0),
  (40040,30040,'PACKSHOT','/assets/img/flavours/strawberry-ice-cream/scoop-shop/packshot/main.png','스트로베리 스쿱 팩샷',0),
  (40041,30041,'PACKSHOT','/assets/img/flavours/vanilla-ice-cream/scoop-shop/packshot/main.png','바닐라 스쿱 팩샷',0),
  (40042,30042,'PACKSHOT','/assets/img/flavours/berry-berry-extraordinary-sorbet/scoop-shop/packshot/main.png','베리베리 엑스트라 오디너리 스쿱 팩샷',0),
  (40043,30043,'PACKSHOT','/assets/img/flavours/sweet-cream-and-cookies-ice-cream/scoop-shop/packshot/main.png','스위트 크림&쿠키 스쿱 팩샷',0);



-- GALLERY (01~05)
-- sort_order는 트리거 자동세팅
INSERT INTO variant_media (id, variant_id, role, url, alt_ko, sort_order) VALUES
  (41001,30001,'GALLERY','/assets/img/flavours/chunky-monkey-ice-cream/pint/gallery/01-tower.avif',NULL,0),
  (41002,30001,'GALLERY','/assets/img/flavours/chunky-monkey-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41003,30001,'GALLERY','/assets/img/flavours/chunky-monkey-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41004,30001,'GALLERY','/assets/img/flavours/chunky-monkey-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41005,30001,'GALLERY','/assets/img/flavours/chunky-monkey-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41006,30002,'GALLERY','/assets/img/flavours/half-baked-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41007,30002,'GALLERY','/assets/img/flavours/half-baked-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41008,30002,'GALLERY','/assets/img/flavours/half-baked-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41009,30002,'GALLERY','/assets/img/flavours/half-baked-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41010,30002,'GALLERY','/assets/img/flavours/half-baked-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41011,30003,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41012,30003,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41013,30003,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41014,30003,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41015,30003,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41016,30004,'GALLERY','/assets/img/flavours/strawberry-cheesecake-ice-cream/pint/gallery/01-tower.png',NULL,0),

  (41021,30005,'GALLERY','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41022,30005,'GALLERY','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41023,30005,'GALLERY','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41024,30005,'GALLERY','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),

  (41026,30006,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41027,30006,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41028,30006,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41029,30006,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41030,30006,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41031,30007,'GALLERY','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41032,30007,'GALLERY','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41033,30007,'GALLERY','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41034,30007,'GALLERY','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41035,30007,'GALLERY','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41036,30008,'GALLERY','/assets/img/flavours/karamel-sutra-core/pint/gallery/01-tower.png',NULL,0),
  (41037,30008,'GALLERY','/assets/img/flavours/karamel-sutra-core/pint/gallery/02-envirolid.jpg',NULL,0),
  (41038,30008,'GALLERY','/assets/img/flavours/karamel-sutra-core/pint/gallery/03-scooped.jpg',NULL,0),
  (41039,30008,'GALLERY','/assets/img/flavours/karamel-sutra-core/pint/gallery/04-enviro.jpg',NULL,0),
  (41040,30008,'GALLERY','/assets/img/flavours/karamel-sutra-core/pint/gallery/05-hero.jpg',NULL,0),

  (41041,30009,'GALLERY','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41042,30009,'GALLERY','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41043,30009,'GALLERY','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41044,30009,'GALLERY','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41045,30009,'GALLERY','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41046,30010,'GALLERY','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41047,30010,'GALLERY','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41048,30010,'GALLERY','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41049,30010,'GALLERY','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41050,30010,'GALLERY','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41051,30011,'GALLERY','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41052,30011,'GALLERY','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41053,30011,'GALLERY','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41054,30011,'GALLERY','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41055,30011,'GALLERY','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41056,30012,'GALLERY','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/gallery/01-tower.avif',NULL,0),
  (41057,30012,'GALLERY','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41058,30012,'GALLERY','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41059,30012,'GALLERY','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41060,30012,'GALLERY','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  (41061,30013,'GALLERY','/assets/img/flavours/vanilla-ice-cream/pint/gallery/01-tower.png',NULL,0),
  (41062,30013,'GALLERY','/assets/img/flavours/vanilla-ice-cream/pint/gallery/02-envirolid.jpg',NULL,0),
  (41063,30013,'GALLERY','/assets/img/flavours/vanilla-ice-cream/pint/gallery/03-scooped.jpg',NULL,0),
  (41064,30013,'GALLERY','/assets/img/flavours/vanilla-ice-cream/pint/gallery/04-enviro.jpg',NULL,0),
  (41065,30013,'GALLERY','/assets/img/flavours/vanilla-ice-cream/pint/gallery/05-hero.jpg',NULL,0),

  -- MINI_CUP (있는 것만)
  (41066,30021,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/mini-cup/gallery/01-tower.png',NULL,0),
  (41071,30022,'GALLERY','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/mini-cup/gallery/01-tower.png',NULL,0),
  (41076,30023,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/mini-cup/gallery/01-tower.png',NULL,0),

  -- SCOOP (있는 것만)
  (41081,30031,'GALLERY','/assets/img/flavours/cherry-garcia-ice-cream/scoop-shop/gallery/01-tower.png',NULL,0),
  (41091,30033,'GALLERY','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/scoop-shop/gallery/01-tower.png',NULL,0),
  (41096,30034,'GALLERY','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/scoop-shop/gallery/01-tower.png',NULL,0),
  (41101,30035,'GALLERY','/assets/img/flavours/chunky-monkey-ice-cream/scoop-shop/gallery/01-tower.avif',NULL,0),
  (41106,30036,'GALLERY','/assets/img/flavours/half-baked-ice-cream/scoop-shop/gallery/01-tower.png',NULL,0),
  (41121,30039,'GALLERY','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/scoop-shop/gallery/01-tower.png',NULL,0),
  (41131,30041,'GALLERY','/assets/img/flavours/vanilla-ice-cream/scoop-shop/gallery/01-tower.png',NULL,0);



-- NUTRITION (pint, mini-cup)
INSERT INTO variant_media (id, variant_id, role, url, alt_ko, sort_order) VALUES
  (42001,30001,'NUTRITION','/assets/img/flavours/chunky-monkey-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42002,30002,'NUTRITION','/assets/img/flavours/half-baked-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42003,30003,'NUTRITION','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42004,30004,'NUTRITION','/assets/img/flavours/strawberry-cheesecake-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42005,30005,'NUTRITION','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42006,30006,'NUTRITION','/assets/img/flavours/cherry-garcia-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42007,30007,'NUTRITION','/assets/img/flavours/coffee-coffee-buzz-buzz-buzz-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42008,30008,'NUTRITION','/assets/img/flavours/karamel-sutra-core/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42009,30009,'NUTRITION','/assets/img/flavours/mint-chocolate-cookie-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42010,30010,'NUTRITION','/assets/img/flavours/new-york-super-fudge-chunk-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42011,30011,'NUTRITION','/assets/img/flavours/peanut-butter-cup-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42012,30012,'NUTRITION','/assets/img/flavours/pistachio-pistachio-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),
  (42013,30013,'NUTRITION','/assets/img/flavours/vanilla-ice-cream/pint/nutrition/473ml.png','영양성분표 473ml',0),

  (42021,30021,'NUTRITION','/assets/img/flavours/chocolate-fudge-brownie-ice-cream/mini-cup/nutrition/120ml.png','영양성분표 120ml',0),
  (42022,30022,'NUTRITION','/assets/img/flavours/chocolate-chip-cookie-dough-ice-cream/mini-cup/nutrition/120ml.png','영양성분표 120ml',0),
  (42023,30023,'NUTRITION','/assets/img/flavours/cherry-garcia-ice-cream/mini-cup/nutrition/120ml.png','영양성분표 120ml',0);



-- 7) Ingredients + SmartLabel (모두)
INSERT INTO variant_ingredients (id, variant_id, ingredients_ko, smartlabel_url) VALUES
  (50001,30001,'크림, 탈지우유, 설탕시럽(설탕, 정제수), 정제수, 설탕, 코코아, 코코아분말, 대두유, 난황, 수수설탕, 전란, 전란액, 소금, 구아검, 카라기난, 바닐라추출물, 맥아분말, 탄산수소나트륨','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100354-0003-en-US-1665758042857/index.html'),

  (50002,30002,'크림, 설탕시럽, 탈지농축우유, 정제수, 설탕, 밀가루, 코코아분말, 갈색 설탕, 가당난황, 대두유, 버터, 계란, 전화당, 초콜릿 리커, 바닐라 추출물, 소금, 계란 흰자, 구아검, 카라기난, 당밀, 코코아버터, 천연향료, 맥아분말','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840101320-0002-en-US-1669212157071/index.html#nutrition'),

  (50003,30003,'크림, 액상당, 농축 탈지유, 물, 코코아, 설탕, 밀가루, 대두유, 계란 노른자, 전화당, 계란, 계란 흰자, 농후제(구아검, 카라기난), 설탕, 바닐라 추출물, 팽창제(중탄산나트륨), 맥아분','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100477-0002-en-US-1668535427889/index.html#nutrition'),

  (50004,30004,'아이스크림믹스[유크림, 탈지우유, 정제수, 설탕시럽 (설탕, 정제수), 가당난황, 구아검, 카라기난], 그라함크래커[기타설탕, 옥수수전분, 카놀라유, 대두유, 밀가루], 딸기다이스 [딸기, 설탕, 구아검, 레몬농축과즙], 치즈케이크베이스[설탕, 정제수, 크림치즈, 향료, 젖산], 딸기퓌레',NULL),

  (50005,30005,'크림, 농축 탈지유, 액상당, 물, 표백하지 않은 밀가루, 설탕, 황설탕, 계란 노른자, 버터, 대두유, 계란, 코코넛 오일, 카카오 매스, 바닐라 추출물, 코코아 파우더, 소금, 농후제(구아검, 카라기난), 당밀, 코코아 버터, 천연착향료, 천연조미료, 버터 오일, 유화제(대두 레시틴).','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100583-0002-en-US-1669211882662/index.html'),

  (50006,30006,'크림, 탈지유, 액상당(설탕, 물), 물, 체리, 설탕, 계란 노른자, 코코넛 오일, (알칼리로 처리한) 코코아, 과일 및 채소 농축액(색소), 코코아 파우더, 구아검, 천연착향료, 레몬 농축액, 카라기난, 유지방, 대두 레시틴.','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100156-0002-en-US-1665758051552/index.html'),

  (50007,30007,'크림, 탈지우유, 설탕시럽(설탕, 정제수), 정제수, 설탕, 코코넛유, 커피추출물, 코코아, 커피, 코코아분말, 대두레시틴, 구아검, 바닐라추출물, 카라기난.','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840298617-0002-en-US-1677511188913/index.html#nutrition'),

  (50008,30008,'크림, 탈지우유, 설탕시럽 (설탕, 정제수), 정제수, 설탕, 우유, 옥수수 시럽, 코코아, 달걀 노른자, 코코넛유, 버터 (크림, 소금), 코코아분말, 유지방, 펙틴, 구아검, 베이킹 소다, 락타아제, 대두 레시틴, 바닐라 추출물, 소금, 카라기난, 천연향료.','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840101542-0002-en-US-1675805403456/index.html#nutrition'),

  (50009,30009,'크림, 탈지우유, 설탕시럽 (설탕, 정제수), 정제수, 가당난황, 구아검, 초콜릿샌드위치쿠키,설탕, 밀가루, 코코넛유, 코코아분말, 해바라기유, 소금, 탄산수소나트륨, 천연향료, 대두레시틴, 페퍼민트추출물.','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100040-0002-en-US-1672414892314/index.html#nutrition'),

  (50010,30010,'크림, 설탕시럽 (설탕, 정제수), 탈지우유, 정제수, 코코아, 설탕, 코코넛유, 피칸, 구운 아몬드 (아몬드, 땅콩유), 달걀 노른자, 코코아, 유지방, 소금, 콩레시틴, 바닐라 추출물, 구아검, 버터유, 땅콩유, 버터 (크림), 천연조미료, 카라기난','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100149-0002-en-US-1670951315103/index.html#nutrition'),

  (50011,30011,'유크림, 탈지농축우유, 설탕 시럽 (설탕, 정제수), 정제수, 땅콩, 설탕, 코코넛유, 계란 노른자, 부분 지방질 땅콩 가루, 땅콩기름, 우유, 코코아 (알칼리 처리), 소금, 구아검, 대두 레시틴, 바닐라 추출물, 카라기난','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840100811-0002-en-US-1675809822278/index.html'),

  (50012,30012,'아이스크림믹스 [유크림, 탈지우유, 설탕시럽 (설탕, 정제수), 정제수, 가당난황, 구아검, 카라기난], 로스티드피스 타치오 [피스타치오, 코코넛유, 소금], 피스타치오향료','https://smartlabel.unileverusa.com/076840101184-0002-en-US/index.html'),

  (50013,30013,'크림, 탈지유, 액상당(설탕, 물), 물, 계란 노른자, 설탕, 구아검, 바닐라 추출물, 바닐라 빈, 카라기난.','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840400058-0002-en-US-1671461174511/index.html#nutrition'),

  (50021,30021,'크림, 액상당, 농축 탈지유, 물, 코코아, 설탕, 밀가루, 대두유, 계란 노른자, 전화당, 계란, 계란 흰자, 농후제(구아검, 카라기난), 설탕, 바닐라 추출물, 팽창제(중탄산나트륨), 맥아분','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840200160-0002-en-US-1701801458882/index.html#nutrition'),

  (50022,30022,'크림, 농축 탈지유, 액상당, 물, 표백하지 않은 밀가루, 설탕, 황설탕, 계란 노른자, 버터, 대두유, 계란, 코코넛 오일, 카카오 매스, 바닐라 추출물, 코코아 파우더, 소금, 농후제(구아검, 카라기난), 당밀, 코코아 버터, 천연착향료, 천연조미료, 버터 오일, 유화제(대두 레시틴).','https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840200276-0002-en-US-1701803145903/index.html#nutrition'),

  (50023,30023,'크림, 탈지유, 액상당(설탕, 물), 물, 체리, 설탕, 계란 노른자, 코코넛 오일, (알칼리로 처리한) 코코아, 과일 및 채소 농축액(색소), 코코아 파우더, 구아검, 천연착향료, 레몬 농축액, 카라기난, 유지방, 대두 레시틴.', 'https://smartlabel.scanbuy.com/3kDXaw4KiY2GQD9DU6973N/preview/076840200153-0003-en-US-1701785653440/index.html#nutrition'),

  (50031,30031,'크림, 탈지유, 액상당(설탕, 물), 물, 체리, 설탕, 계란 노른자, 코코넛 오일, (알칼리로 처리한) 코코아, 과일 및 채소 농축액(색소), 코코아 파우더, 구아검, 천연착향료, 레몬 농축액, 카라기난, 유지방, 대두 레시틴.',NULL),

  (50032,30032,'유크림, 설탕시럽(설탕, 정제수), 탈지농축우유, 정제수, 코코아분말, 가당난황, 구아검, 카라기난',NULL),

  (50033,30033,'크림, 농축 탈지유, 액상당, 물, 표백하지 않은 밀가루, 설탕, 황설탕, 계란 노른자, 버터, 대두유, 계란, 코코넛 오일, 카카오 매스, 바닐라 추출물, 코코아 파우더, 소금, 농후제(구아검, 카라기난), 당밀, 코코아 버터, 천연착향료, 천연조미료, 버터 오일, 유화제(대두 레시틴).',NULL),

  (50034,30034,'크림, 액상당, 농축 탈지유, 물, 코코아, 설탕, 밀가루, 대두유, 계란 노른자, 전화당, 계란, 계란 흰자, 농후제(구아검, 카라기난), 설탕, 바닐라 추출물, 팽창제(중탄산나트륨), 맥아분',NULL),

  (50035,30035,'크림, 탈지우유, 설탕시럽(설탕, 정제수), 정제수, 설탕, 코코아, 코코아분말, 대두유, 난황, 수수설탕, 전란, 전란액, 소금, 구아검, 카라기난, 바닐라추출물, 맥아분말, 탄산수소나트륨',NULL),

  (50036,30036,'크림, 설탕시럽, 탈지농축우유, 정제수, 설탕, 밀가루, 코코아분말, 갈색 설탕, 가당난황, 대두유, 버터, 계란, 전화당, 초콜릿 리커,바닐라 추출물, 소금, 계란 흰자, 구아검, 카라기난, 당밀, 코코아버터, 천연향료, 맥아분말',NULL),

  (50037,30037,'물, 액상당(설탕, 물), 고형 옥수수 시럽, 레몬 퓨레, 이눌린, 레몬 농축액, 펙틴, 로커스트빈검, 덱스트로오스.',NULL),

  (50038,30038,'크림, 탈지유, 액상당(설탕, 물), 물, 퍼지 덩어리[설탕, 코코넛 오일, (알칼리로 처리한) 코코아, 코코아, 유지방, 대두 레시틴, 천연착향료], 계란 노른자, 천연착향료, 구아검, 카라기난.',NULL),

  (50039,30039,'크림, 설탕시럽 (설탕, 정제수), 탈지우유, 정제수, 코코아, 설탕, 코코넛유, 피칸, 구운 아몬드 (아몬드, 땅콩유), 달걀 노른자, 코코아, 유지방, 소금, 콩레시틴, 바닐라 추출물, 구아검, 버터유, 땅콩유, 버터 (크림), 천연조미료, 카라기난',NULL),

  (50040,30040,'크림, 탈지유, 딸기, 액상당(설탕, 물), 물, 설탕, 계란 노른자, 구아검, 카라기난.',NULL),

  (50041,30041,'크림, 탈지유, 액상당(설탕, 물), 물, 계란 노른자, 설탕, 구아검, 바닐라 추출물, 바닐라 빈, 카라기난.',NULL),

  (50042,30042,'물, 액상당(설탕, 물), 블루베리 농축 퓨레, 라즈베리 퓨레, 고형 옥수수 시럽, 블루베리 농축액, 설탕, 이눌린(이눌린, 설탕, 과당, 포도당), 블루베리 농축액, 레몬 농축액, 펙틴, 로커스트빈검, 덱스트로오스, 엘더베리 농축액(색소).',NULL),

  (50043,30043,'크림, 탈지유, 액상당(설탕, 물), 물, 설탕, 밀가루, 계란 노른자, 코코넛 오일, (알칼리로 처리한)코코아, 해바라기유, 소금, 베이킹 소다, 천연착향료, 구아검, 대두 레시틴, 카라기난.',NULL);



-- 8) Values-led sourcing 매핑
-- pint
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30001, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30002, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','FAIRTRADE','FREE_RANGE_EGGS');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30003, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','GREYSTON_BROWNIES','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30004, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','OPEN_CHAIN_SOURCING','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30005, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30006, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30007, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30008, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30009, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30010, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30011, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30012, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30013, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');

-- mini-cup
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30021, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','GREYSTON_BROWNIES','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30022, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30023, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');

-- scoop
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30031, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30032, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30033, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30034, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','GREYSTON_BROWNIES','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30035, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30036, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','FAIRTRADE','FREE_RANGE_EGGS');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30037, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30038, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30039, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30040, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30041, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30042, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');
INSERT INTO variant_sourcing (variant_id, feature_id, sort_order)
SELECT 30043, id, 0 FROM sourcing_feature WHERE code IN ('NON_GMO','CAGE_FREE_EGGS','FAIRTRADE','CARING_DAIRY','RESPONSIBLY_SOURCED_PACKAGING');

-- 9) Dietary certifications 매핑
-- pint
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30001, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30003, id, 0 FROM dietary_cert WHERE code IN ('HALAL','KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30006, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30007, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30008, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY','GLUTEN_FREE');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30009, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30010, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY','GLUTEN_FREE');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30011, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY','GLUTEN_FREE');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30012, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY','GLUTEN_FREE');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30013, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');

-- mini-cup
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30021, id, 0 FROM dietary_cert WHERE code IN ('HALAL','KOSHER_DAIRY');
-- 30022: 빈값(미지정)
-- 30023: 빈값(미지정)

-- scoop
-- 30031 (cherry): 빈값
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30032, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY','GLUTEN_FREE');
-- 30033: 빈값
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30034, id, 0 FROM dietary_cert WHERE code IN ('HALAL','KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30035, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30036, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
-- 30037 sorbet: 빈값
-- 30038: 빈값
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30039, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY','GLUTEN_FREE');
-- 30040: 빈값
INSERT INTO variant_cert (variant_id, cert_id, sort_order)
SELECT 30041, id, 0 FROM dietary_cert WHERE code IN ('KOSHER_DAIRY');
-- 30042: 빈값
-- 30043: 빈값



/* ================================
   tag + tag_alias
   ================================ */

-- Tags
INSERT INTO tag (slug, name_ko) VALUES
  ('chocolate',     '초콜릿'),
  ('vanilla',       '바닐라'),
  ('strawberry',    '스트로베리'),
  ('mint',          '민트'),
  ('peanut-butter', '피넛버터'),
  ('cherry',        '체리'),
  ('cheesecake',    '치즈케이크'),
  ('cookie-dough',  '쿠키 도우'),
  ('brownie',       '브라우니'),
  ('coffee',        '커피'),
  ('caramel',       '카라멜'),
  ('sorbet',        '소르베'),
  ('berry',         '베리'),
  ('nut',           '견과류'),
  ('pistachio',     '피스타치오'),
  ('banana',        '바나나'),
  ('fudge',         '퍼지'),
  ('chunk',         '청크');

-- Aliases

-- chocolate
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '초콜릿' alias UNION ALL SELECT '초코' UNION ALL SELECT 'choco' UNION ALL SELECT 'chocolate') a
ON t.slug = 'chocolate';

-- vanilla
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '바닐라' alias UNION ALL SELECT 'vanilla') a
ON t.slug = 'vanilla';

-- strawberry
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '딸기' alias UNION ALL SELECT '스트로베리' UNION ALL SELECT 'strawberry') a
ON t.slug = 'strawberry';

-- mint
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '민트' alias UNION ALL SELECT '페퍼민트' UNION ALL SELECT 'peppermint' UNION ALL SELECT 'mint') a
ON t.slug = 'mint';

-- peanut-butter
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (
  SELECT '피넛버터' alias UNION ALL SELECT '땅콩버터' UNION ALL SELECT 'peanut' UNION ALL SELECT 'peanut butter'
) a
ON t.slug = 'peanut-butter';

-- cherry
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '체리' alias UNION ALL SELECT 'cherry') a
ON t.slug = 'cherry';

-- cheesecake
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '치즈케이크' alias UNION ALL SELECT 'cheesecake') a
ON t.slug = 'cheesecake';

-- cookie-dough
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (
  SELECT '쿠키 도우' alias UNION ALL SELECT '쿠키도우' UNION ALL
  SELECT 'cookie' UNION ALL SELECT 'cookie dough'
) a
ON t.slug = 'cookie-dough';

-- brownie
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '브라우니' alias UNION ALL SELECT 'brownie') a
ON t.slug = 'brownie';

-- coffee
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '커피' alias UNION ALL SELECT 'coffee' UNION ALL SELECT '에스프레소' UNION ALL SELECT 'espresso') a
ON t.slug = 'coffee';

-- caramel
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '카라멜' alias UNION ALL SELECT 'caramel') a
ON t.slug = 'caramel';

-- sorbet
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '소르베' alias UNION ALL SELECT 'sorbet') a
ON t.slug = 'sorbet';

-- berry
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (
  SELECT '베리' alias UNION ALL SELECT 'berry' UNION ALL
  SELECT '블루베리' UNION ALL SELECT '라즈베리'
) a
ON t.slug = 'berry';

-- nut
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '견과' alias UNION ALL SELECT '견과류' UNION ALL SELECT '넛츠' UNION ALL SELECT 'nuts' UNION ALL SELECT 'nut') a
ON t.slug = 'nut';

-- pistachio
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '피스타치오' alias UNION ALL SELECT 'pistachio') a
ON t.slug = 'pistachio';

-- banana
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '바나나' alias UNION ALL SELECT 'banana') a
ON t.slug = 'banana';

-- fudge
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '퍼지' alias UNION ALL SELECT 'fudge') a
ON t.slug = 'fudge';

-- chunk
INSERT INTO tag_alias (tag_id, alias)
SELECT id, a.alias FROM tag t
JOIN (SELECT '청크' alias UNION ALL SELECT 'chunk' UNION ALL SELECT 'chunks') a
ON t.slug = 'chunk';



/* ============================================================
   flavour_tag mapping (flavour.slug × tag.slug)
   ============================================================ */

-- 20001 chunky-monkey-ice-cream  : banana, nut, chocolate, fudge, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='banana'    WHERE f.slug='chunky-monkey-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='nut'        WHERE f.slug='chunky-monkey-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate'  WHERE f.slug='chunky-monkey-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'      WHERE f.slug='chunky-monkey-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'      WHERE f.slug='chunky-monkey-ice-cream';

-- 20002 half-baked-ice-cream : chocolate, vanilla, cookie-dough, brownie, fudge, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate'    WHERE f.slug='half-baked-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='vanilla'      WHERE f.slug='half-baked-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='cookie-dough' WHERE f.slug='half-baked-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='brownie'      WHERE f.slug='half-baked-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'        WHERE f.slug='half-baked-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'        WHERE f.slug='half-baked-ice-cream';

-- 20003 chocolate-fudge-brownie-ice-cream : chocolate, fudge, brownie, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate'   WHERE f.slug='chocolate-fudge-brownie-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'       WHERE f.slug='chocolate-fudge-brownie-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='brownie'     WHERE f.slug='chocolate-fudge-brownie-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'       WHERE f.slug='chocolate-fudge-brownie-ice-cream';

-- 20004 strawberry-cheesecake-ice-cream : strawberry, cheesecake
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='strawberry'  WHERE f.slug='strawberry-cheesecake-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='cheesecake' WHERE f.slug='strawberry-cheesecake-ice-cream';

-- 20005 chocolate-chip-cookie-dough-ice-cream : cookie-dough, chocolate, vanilla, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='cookie-dough' WHERE f.slug='chocolate-chip-cookie-dough-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate'    WHERE f.slug='chocolate-chip-cookie-dough-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='vanilla'      WHERE f.slug='chocolate-chip-cookie-dough-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'        WHERE f.slug='chocolate-chip-cookie-dough-ice-cream';

-- 20006 cherry-garcia-ice-cream : cherry, chocolate, fudge, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='cherry'     WHERE f.slug='cherry-garcia-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate'  WHERE f.slug='cherry-garcia-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'      WHERE f.slug='cherry-garcia-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'      WHERE f.slug='cherry-garcia-ice-cream';

-- 20007 coffee-coffee-buzz-buzz-buzz-ice-cream : coffee, chocolate, fudge
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='coffee'     WHERE f.slug='coffee-coffee-buzz-buzz-buzz-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='coffee-coffee-buzz-buzz-buzz-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'     WHERE f.slug='coffee-coffee-buzz-buzz-buzz-ice-cream';

-- 20008 karamel-sutra-core : caramel, chocolate, fudge, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='caramel'    WHERE f.slug='karamel-sutra-core'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='karamel-sutra-core'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'     WHERE f.slug='karamel-sutra-core'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'     WHERE f.slug='karamel-sutra-core';

-- 20009 mint-chocolate-cookie-ice-cream : mint, chocolate, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='mint'       WHERE f.slug='mint-chocolate-cookie-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='mint-chocolate-cookie-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'     WHERE f.slug='mint-chocolate-cookie-ice-cream';

-- 20010 new-york-super-fudge-chunk-ice-cream : chocolate, fudge, chunk, nut
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='new-york-super-fudge-chunk-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='fudge'     WHERE f.slug='new-york-super-fudge-chunk-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'     WHERE f.slug='new-york-super-fudge-chunk-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='nut'       WHERE f.slug='new-york-super-fudge-chunk-ice-cream';

-- 20011 peanut-butter-cup-ice-cream : peanut-butter, chocolate, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='peanut-butter' WHERE f.slug='peanut-butter-cup-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate'    WHERE f.slug='peanut-butter-cup-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'        WHERE f.slug='peanut-butter-cup-ice-cream';

-- 20012 pistachio-pistachio-ice-cream : pistachio, nut
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='pistachio' WHERE f.slug='pistachio-pistachio-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='nut'      WHERE f.slug='pistachio-pistachio-ice-cream';

-- 20013 vanilla-ice-cream : vanilla
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='vanilla' WHERE f.slug='vanilla-ice-cream';

-- 20014 chocolate-ice-cream : chocolate
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='chocolate-ice-cream';

-- 20015 lemonade-sorbet : sorbet
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='sorbet' WHERE f.slug='lemonade-sorbet';

-- 20016 mint-chocolate-chunk-ice-cream : mint, chocolate, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='mint'       WHERE f.slug='mint-chocolate-chunk-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='mint-chocolate-chunk-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'     WHERE f.slug='mint-chocolate-chunk-ice-cream';

-- 20017 strawberry-ice-cream : strawberry
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='strawberry' WHERE f.slug='strawberry-ice-cream';

-- 20018 berry-berry-extraordinary-sorbet : berry, sorbet
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='berry'  WHERE f.slug='berry-berry-extraordinary-sorbet'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='sorbet' WHERE f.slug='berry-berry-extraordinary-sorbet';

-- 20019 sweet-cream-and-cookies-ice-cream : vanilla, chocolate, chunk
INSERT INTO flavour_tag (flavour_id, tag_id)
SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='vanilla'   WHERE f.slug='sweet-cream-and-cookies-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chocolate' WHERE f.slug='sweet-cream-and-cookies-ice-cream'
UNION ALL SELECT f.id, t.id FROM flavour f JOIN tag t ON t.slug='chunk'     WHERE f.slug='sweet-cream-and-cookies-ice-cream';


-- ======================
-- Article (whats-new)
-- ======================
INSERT INTO article (slug, title_ko, excerpt_ko, content_ko, is_active, created_at, updated_at, published_at)
VALUES (
  'free-cone-day-flavor',
  '어떻게 하면 보다 특별한 Free Cone day (프리 콘 데이)를 만들 수 있을까요?',
  'Free Cone day (프리 콘 데이)를 기다리고 계시는 여러분을 위해, 맛있는 아이스크림 뿐만 아니라 여러분의 관심사나 가치관에 맞는 맛을 고르실 수 있도록 이 가이드를 만들었어요.',
  '<p>여러분이 선택한 아이스크림이 세상을 더 긍정적으로 만드는 데 도움이 될 수 있다는 사실, 알고 계시나요? <br/><br/>
                                Free Cone day (프리 콘 데이)를 기다리고 계시는 여러분을 위해, 맛있는 아이스크림 뿐만 아니라 여러분의 관심사나 가치관에 맞는 맛을 고르실 수 있도록 이 가이드를 만들었어요. 벤앤제리스의 모든 아이스크림은 크고 작은 방식으로 농부, 지역 공동체, 환경, 그리고 세상의 긍정적인 변화를 돕고 있답니다. 벤앤제리스는 앞으로도 더 노력할게요! 이번 2023년 4월 3일, Free Cone day (프리 콘 데이)에 함께하셔서 가장 중요하다고 생각하시는 문제들에 대한 해결 방법을 함께 찾아나가요! </p>
<p> </p>
<ol class="listicle">
<li>
<article class="content-tile view-default">
<div class="content-tile-image article">
<picture>
<img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/flavor-listicle-1.png"/>
</picture>
</div>
<div class="content-tile-content">

<div class="content-tile-body" id="tile-body-09454b28-27c5-4235-b70c-503fbbb87522"><p>그렇다면 초콜릿 퍼지 브라우니 또는 하프 베이크를 선택해 보세요! 이 두 가지 맛에 들어간 퍼지 브라우니는 뉴욕, 용커스 지역의 사회적 기업인 그레이스톤 베이커리에서 만들어졌습니다. 이 베이커리는 고용 장벽에 직면한 사람들에게 직업 기회를 제공함으로써 삶을 바꿀 수 있도록 돕습니다. 아이스크림 한 스쿱이 단순한 간식이 아닌, 더 큰 의미를 지니게 되죠.</p></div>
</div>
</article>
</li>
<li>
<article class="content-tile view-default">
<div class="content-tile-image article">
<picture>
<img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/flavor-listicle-2.png"/>
</picture>
</div>
<div class="content-tile-content">
<div class="content-tile-body" id="tile-body-2b92300c-8885-4d79-bb73-0a56f3baf617"><p>공정무역(Fairtrade)을 응원하시나요? 그렇다면 베리베리 엑스트라오디너리 소르베, 체리 가르시아, 스트로베리 치즈케이크를 고르세요! 이 제품들은 공정무역 인증 재료로 만들어져 농부들이 정당한 대가를 받을 수 있도록 보장합니다. 맛있는 아이스크림을 즐기면서 더 나은 세상을 만드는 데 동참할 수 있습니다.</p></div>
</div>
</article>
</li>
<li>
<article class="content-tile view-default">
<div class="content-tile-image article">
<picture>
<img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/flavor-listicle-3.png"/>
</picture>
</div>
<div class="content-tile-content">
<div class="content-tile-body" id="tile-body-cc16bf17-58ea-4d86-8db1-528f10d54c67"><p>동물복지와 환경을 지지한다면? 청키 몽키, 피스타치오 피스타치오, 피넛 버터 컵을 추천합니다. 우리는 케이지 프리(Cage-free) 달걀과 Non-GMO 원재료, 친환경 포장재를 사용하는 등 더 지속가능한 방법을 선택합니다. 여러분의 선택이 변화를 만듭니다.</p></div>
</div>
</article>
</li>
</ol>',
  1, NOW(), NOW(), '2023-03-01 00:00:00'
);

INSERT INTO article (slug, title_ko, excerpt_ko, content_ko, is_active, created_at, updated_at, published_at)
VALUES (
  'free-cone-day-history',
  'Free Cone day (프리 콘 데이): 미국 버몬트에서 세계적인 축제가 되기까지',
  '벤앤제리스를 아끼고 사랑해 주시는 마음만큼, 벤앤제리스 역시 Free Cone day (프리 콘 데이)를 통해 팬 여러분의 사랑과 성원에 감사의 마음을 전하고자 합니다.',
  '<p>벤앤제리스를 아끼고 사랑해 주시는 마음만큼, 벤앤제리스 역시 Free Cone day (프리 콘 데이)를 통해 팬 여러분의 사랑과 성원에 감사의 마음을 전하고자 합니다. </p>
<p> </p>
<p><strong>1979</strong></p>
<img alt="Ben &amp; Jerry''s Free Cone Day History - 1979" src="/assets/img/misc/fcd-history-1979.png"/>
<p>벤앤제리스의 첫 Free Cone day (프리 콘 데이)는 1979년 5월 5일이었습니다. 당시 버몬트 벌링턴의 작은 아이스크림 가게에서 시작된 이 이벤트는, 한 해 동안 저희를 응원해 주신 고객들에게 감사의 의미로 아이스크림을 무료로 나눠드린 것이었습니다.</p>
<p><strong>1980s</strong></p>
<img alt="Ben &amp; Jerry''s Free Cone Day History - 1980s" src="/assets/img/misc/fcd-history-1980s.png"/>
<p>이후 매년 Free Cone day는 이어졌고, 입소문을 타고 점점 더 많은 사람들이 참여하는 행사가 되었습니다. 아이스크림은 단순한 디저트를 넘어, 사람들을 하나로 모으는 상징이 되었습니다.</p>
<p><strong>1990s</strong></p>
<img alt="Ben &amp; Jerry''s Free Cone Day History - 1990s" src="/assets/img/misc/fcd-history-1990s.png"/>
<p>1990년대에 들어서면서 Free Cone day는 국제적인 행사로 확대되었습니다. 전 세계 여러 나라에서 벤앤제리스 스쿱샵이 동참하며, 지역 사회에 환원하는 축제로 자리잡았습니다.</p>
<p><strong>2000s</strong></p>
<img alt="Ben &amp; Jerry''s Free Cone Day History - 2000s" src="/assets/img/misc/fcd-history-2000s.png"/>
<p>2000년대에도 이 전통은 계속 이어졌습니다. Free Cone day는 단순한 무료 아이스크림 이벤트를 넘어, 지역 사회와 환경, 사회적 가치에 대한 우리의 약속을 공유하는 자리가 되었습니다.</p>
<p><strong>Today</strong></p>
<img alt="Ben &amp; Jerry''s Free Cone Day History - Today" src="/assets/img/misc/fcd-history-today.png"/>
<p>오늘날 Free Cone day는 전 세계적으로 수많은 팬들이 기다리는 날이 되었습니다. 우리는 앞으로도 이 특별한 날을 통해 감사의 마음을 전하고, 함께 더 나은 세상을 만들어 가기를 희망합니다.</p>',
  1, NOW(), NOW(), '2023-03-01 00:00:00'
);


INSERT INTO article (slug, title_ko, excerpt_ko, content_ko, is_active, created_at, updated_at, published_at)
VALUES (
  'top-ben-jerrys-flavours-of-2022',
  'Top Ben & Jerry’s Flavours of 2022',
  'It’s been a swirl of a year! And through it all, Ben & Jerry’s has been there for you. Those late-night hangouts with a bowl of Chocolate Fudge Brownie, the weekend brunches with a scoop of Strawberry Cheesecake — thank you for making us part of your moments. There was a lot of euphoria in 2022, and these flavours got the most love:',
  '<p>It’s been a swirl of a year! And through it all, Ben &amp; Jerry’s has been there for you. Those late-night hangouts with a bowl of Chocolate Fudge Brownie, the weekend brunches with a scoop of Strawberry Cheesecake — thank you for making us part of your moments.</p>
<h3>Top Flavours of 2022</h3>
<ol class="listicle">
  <li>
    <article class="content-tile view-default">
      <div class="content-tile-image article">
        <picture>
          <img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/top-flavours-2022-1.png"/>
        </picture>
      </div>
      <div class="content-tile-content">
        <div class="content-tile-body"><p>Chocolate Fudge Brownie — 꾸준히 사랑받는 진한 초콜릿과 브라우니 조합!</p></div>
      </div>
    </article>
  </li>
  <li>
    <article class="content-tile view-default">
      <div class="content-tile-image article">
        <picture>
          <img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/top-flavours-2022-2.png"/>
        </picture>
      </div>
      <div class="content-tile-content">
        <div class="content-tile-body"><p>Half Baked — 쿠키 도우와 퍼지 브라우니의 완벽한 만남.</p></div>
      </div>
    </article>
  </li>
  <li>
    <article class="content-tile view-default">
      <div class="content-tile-image article">
        <picture>
          <img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/top-flavours-2022-3.png"/>
        </picture>
      </div>
      <div class="content-tile-content">
        <div class="content-tile-body"><p>Chocolate Chip Cookie Dough — 혁신적이었던 클래식 플레이버.</p></div>
      </div>
    </article>
  </li>
  <li>
    <article class="content-tile view-default">
      <div class="content-tile-image article">
        <picture>
          <img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/top-flavours-2022-4.png"/>
        </picture>
      </div>
      <div class="content-tile-content">
        <div class="content-tile-body"><p>Strawberry Cheesecake — 달콤한 딸기와 고소한 치즈케이크 스월.</p></div>
      </div>
    </article>
  </li>
  <li>
    <article class="content-tile view-default">
      <div class="content-tile-image article">
        <picture>
          <img aria-hidden="true" class="" loading="lazy" src="/assets/img/misc/top-flavours-2022-5.png"/>
        </picture>
      </div>
      <div class="content-tile-content">
        <div class="content-tile-body"><p>Cherry Garcia — 전설적인 락 밴드에서 영감을 받은 체리와 초콜릿의 조합.</p></div>
      </div>
    </article>
  </li>
</ol>
<p>Did your favourite make the list? If not, there’s always next year — and plenty of scoops to go around!</p>',
  1, NOW(), NOW(), '2022-11-29 00:00:00'
);


-- ======================
-- Recommendations (같은 카테고리의 다른 3가지 맛)
-- 파인트 보유 → 파인트로 매핑, 파인트 없고 스쿱만 보유 → 스쿱으로 매핑
-- ======================

-- 30001 chunky-monkey-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30001,30010,1),
  (30001,30006,2),
  (30001,30011,3);

-- 30002 half-baked-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30002,30005,1),
  (30002,30003,2),
  (30002,30009,3);

-- 30003 chocolate-fudge-brownie-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30003,30009,1),
  (30003,30002,2),
  (30003,30004,3);

-- 30004 strawberry-cheesecake-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30004,30009,1),
  (30004,30006,2),
  (30004,30003,3);

-- 30005 chocolate-chip-cookie-dough-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30005,30013,1),
  (30005,30002,2),
  (30005,30010,3);

-- 30006 cherry-garcia-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30006,30001,1),
  (30006,30004,2),
  (30006,30010,3);

-- 30007 coffee-coffee-buzz-buzz-buzz-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30007,30009,1),
  (30007,30013,2),
  (30007,30011,3);

-- 30008 karamel-sutra-core (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30008,30004,1),
  (30008,30010,2),
  (30008,30009,3);

-- 30009 mint-chocolate-cookie-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30009,30004,1),
  (30009,30003,2),
  (30009,30013,3);

-- 30010 new-york-super-fudge-chunk-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30010,30001,1),
  (30010,30011,2),
  (30010,30012,3);

-- 30011 peanut-butter-cup-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30011,30012,1),
  (30011,30010,2),
  (30011,30009,3);

-- 30012 pistachio-pistachio-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30012,30011,1),
  (30012,30010,2),
  (30012,30009,3);

-- 30013 vanilla-ice-cream (pint)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30013,30005,1),
  (30013,30009,2),
  (30013,30007,3);

  -- 30032 chocolate-ice-cream (scoop-shop only)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30032,30038,1),
  (30032,30039,2),
  (30032,30031,3);

-- 30037 lemonade-sorbet (scoop-shop only)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30037,30042,1),
  (30037,30032,2),
  (30037,30039,3);

-- 30038 mint-chocolate-chunk-ice-cream (scoop-shop only)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30038,30032,1),
  (30038,30039,2),
  (30038,30031,3);

-- 30040 strawberry-ice-cream (scoop-shop only)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30040,30031,1),
  (30040,30032,2);

-- 30042 berry-berry-extraordinary-sorbet (scoop-shop only)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30042,30037,1),
  (30042,30032,2),
  (30042,30039,3);

-- 30043 sweet-cream-and-cookies-ice-cream (scoop-shop only)
INSERT INTO variant_reco (source_variant_id, target_variant_id, slot) VALUES
  (30043,30034,1),
  (30043,30032,2),
  (30043,30038,3);


/* ======================
   Backfill
   ====================== */

-- 1) product_variant.sort_order 초기화
UPDATE product_variant
SET sort_order = NULL;

-- 2) flavour_sort_rank 재계산
UPDATE flavour f
JOIN flavour_type ft ON ft.id = f.flavour_type_id
SET f.flavour_sort_rank = CASE
  WHEN f.is_new = 1 THEN 0
  ELSE COALESCE(ft.sort_priority, 9)
END;

-- 3)  variant_sourcing.sort_order 보정
UPDATE variant_sourcing vs
JOIN sourcing_feature sf ON vs.feature_id = sf.id
SET vs.sort_order = CASE sf.code
  WHEN 'NON_GMO'                       THEN 1
  WHEN 'CAGE_FREE_EGGS'                THEN 2
  WHEN 'FAIRTRADE'                     THEN 3
  WHEN 'FREE_RANGE_EGGS'               THEN 4
  WHEN 'GREYSTON_BROWNIES'             THEN 5
  WHEN 'CARING_DAIRY'                  THEN 6
  WHEN 'OPEN_CHAIN_SOURCING'           THEN 7
  WHEN 'RESPONSIBLY_SOURCED_PACKAGING' THEN 8
  ELSE 99
END;

-- 4) variant_cert.sort_order 보정
UPDATE variant_cert vc
JOIN dietary_cert dc ON vc.cert_id = dc.id
SET vc.sort_order = CASE dc.code
  WHEN 'HALAL'        THEN 1
  WHEN 'KOSHER_DAIRY' THEN 2
  WHEN 'GLUTEN_FREE'  THEN 3
  ELSE 99
END;



-- 3) 최신 cohort 승격 (선택)
-- CALL promote_latest_cohort();

SET FOREIGN_KEY_CHECKS = 1;
