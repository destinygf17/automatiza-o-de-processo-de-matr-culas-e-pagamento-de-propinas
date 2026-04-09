-- ============================================================
-- SCHEMA COMPLETO - Sistema de Gestão Escolar
-- ============================================================

-- Extensão para suporte a UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- TIPOS ENUM
-- ============================================================

-- Estado de um ano lectivo
CREATE TYPE enum_estado_ano_lectivo AS ENUM (
    'ABERTO',
    'ENCERRADO',
    'SUSPENSO'
);

-- Estado de validação da matrícula pela secretaria
CREATE TYPE enum_estado_secretaria AS ENUM (
    'PENDENTE',
    'VALIDADO',
    'REJEITADO'
);

-- Estado de aprovação da matrícula pela contabilidade
CREATE TYPE enum_estado_contabilidade AS ENUM (
    'PENDENTE',
    'APROVADO',
    'REJEITADO'
);

-- Estado de envio de uma notificação
CREATE TYPE enum_estado_notificacao AS ENUM (
    'PENDENTE',
    'ENVIADO',
    'FALHOU',
    'CANCELADO'
);

-- Género do aluno (usado em t10_bilhete_aluno)
CREATE TYPE enum_genero AS ENUM (
    'MASCULINO',
    'FEMININO'
);

-- ============================================================
-- TABELAS
-- ============================================================

-- ------------------------------------------------------------
-- t01_perfil
-- ------------------------------------------------------------
CREATE TABLE t01_perfil (
    id          INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    descricao   VARCHAR(100) NOT NULL
);

-- ------------------------------------------------------------
-- t02_funcionario
-- ------------------------------------------------------------
CREATE TABLE t02_funcionario (
    uuid_funcionario    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    id_perfil           INT          NOT NULL,
    nome                VARCHAR(150) NOT NULL,
    telefone            VARCHAR(20),
    senha               VARCHAR(255) NOT NULL,
    salt                VARCHAR(255) NOT NULL,
    estado              BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_funcionario_perfil
        FOREIGN KEY (id_perfil) REFERENCES t01_perfil (id)
);

-- ------------------------------------------------------------
-- t03_ano_lectivo
-- ------------------------------------------------------------
CREATE TABLE t03_ano_lectivo (
    id                  INT                     PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    uuid_funcionario    UUID                    NOT NULL,
    ano_lectivo         DATE                    NOT NULL,
    abertura            TIMESTAMP               NOT NULL,
    encerramento        TIMESTAMP,
    estado              enum_estado_ano_lectivo NOT NULL DEFAULT 'ABERTO',

    CONSTRAINT fk_ano_lectivo_funcionario
        FOREIGN KEY (uuid_funcionario) REFERENCES t02_funcionario (uuid_funcionario)
);

-- ------------------------------------------------------------
-- t04_provincia
-- ------------------------------------------------------------
CREATE TABLE t04_provincia (
    id      INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    nome    VARCHAR(100) NOT NULL
);

-- ------------------------------------------------------------
-- t05_municipio
-- ------------------------------------------------------------
CREATE TABLE t05_municipio (
    id              INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    id_provincia    INT          NOT NULL,
    nome            VARCHAR(100) NOT NULL,

    CONSTRAINT fk_municipio_provincia
        FOREIGN KEY (id_provincia) REFERENCES t04_provincia (id)
);

-- ------------------------------------------------------------
-- t06_bairro
-- ------------------------------------------------------------
CREATE TABLE t06_bairro (
    id              INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    id_municipio    INT          NOT NULL,
    nome            VARCHAR(100) NOT NULL,

    CONSTRAINT fk_bairro_municipio
        FOREIGN KEY (id_municipio) REFERENCES t05_municipio (id)
);

-- ------------------------------------------------------------
-- t07_encarregado
-- ------------------------------------------------------------
CREATE TABLE t07_encarregado (
    uuid_encarregado    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nome                VARCHAR(150) NOT NULL,
    email               VARCHAR(255) NOT NULL,
    profissao           VARCHAR(100),
    telefone            VARCHAR(20),
    local_trabalho      TEXT,
    nif                 VARCHAR(20)  UNIQUE
);

-- ------------------------------------------------------------
-- t08_grau_parentesco
-- ------------------------------------------------------------
CREATE TABLE t08_grau_parentesco (
    id          INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    descricao   VARCHAR(100) NOT NULL   -- ex: 'Pai', 'Mãe', 'Avó', 'Tio', 'Tutor'
);

-- ------------------------------------------------------------
-- t09_aluno
-- ------------------------------------------------------------
CREATE TABLE t09_aluno (
    uuid_aluno          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    uuid_encarregado    UUID         NOT NULL,
    nome                VARCHAR(150) NOT NULL,
    id_grau_parentesco  INT          NOT NULL,
    data_cadastro       TIMESTAMP    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_aluno_encarregado
        FOREIGN KEY (uuid_encarregado) REFERENCES t07_encarregado (uuid_encarregado),

    CONSTRAINT fk_aluno_grau_parentesco
        FOREIGN KEY (id_grau_parentesco) REFERENCES t08_grau_parentesco (id)
);

-- ------------------------------------------------------------
-- t10_bilhete_aluno
-- ------------------------------------------------------------
CREATE TABLE t10_bilhete_aluno (
    uuid_aluno              UUID         PRIMARY KEY,
    genero                  enum_genero,
    pai                     VARCHAR(150),
    mae                     VARCHAR(150),
    data_nascimento         DATE,
    natural_de              VARCHAR(100),
    id_arquivo              INT,          -- referência externa (ex: tabela de ficheiros)
    bi_numero               VARCHAR(20),
    arquivo_identificacao   VARCHAR(255),
    data_emissao            DATE,
    data_validade           DATE,
    estado                  BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_bilhete_aluno
        FOREIGN KEY (uuid_aluno) REFERENCES t09_aluno (uuid_aluno)
);

-- ------------------------------------------------------------
-- t11_endereco
-- ------------------------------------------------------------
CREATE TABLE t11_endereco (
    uuid_aluno      UUID         PRIMARY KEY,
    id_bairro       INT          NOT NULL,
    rua             VARCHAR(150),
    numero_casa     VARCHAR(20),

    CONSTRAINT fk_endereco_aluno
        FOREIGN KEY (uuid_aluno) REFERENCES t09_aluno (uuid_aluno),

    CONSTRAINT fk_endereco_bairro
        FOREIGN KEY (id_bairro) REFERENCES t06_bairro (id)
);

-- ------------------------------------------------------------
-- t12_matricula
-- ------------------------------------------------------------
CREATE TABLE t12_matricula (
    id                      INT                       PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    id_ano_lectivo          INT                       NOT NULL,
    uuid_funcionario        UUID,                     -- NULL quando submetido pelo público; preenchido após acção da secretaria
    uuid_aluno              UUID                      NOT NULL,
    estado_secretaria       enum_estado_secretaria    NOT NULL DEFAULT 'PENDENTE',
    estado_contabilidade    enum_estado_contabilidade NOT NULL DEFAULT 'PENDENTE',
    data_matricula          TIMESTAMP                 NOT NULL DEFAULT NOW(),
    validado_secretaria_em  TIMESTAMP,
    aprovado_contab_em      TIMESTAMP,

    CONSTRAINT fk_matricula_ano_lectivo
        FOREIGN KEY (id_ano_lectivo) REFERENCES t03_ano_lectivo (id),

    CONSTRAINT fk_matricula_funcionario
        FOREIGN KEY (uuid_funcionario) REFERENCES t02_funcionario (uuid_funcionario),

    CONSTRAINT fk_matricula_aluno
        FOREIGN KEY (uuid_aluno) REFERENCES t09_aluno (uuid_aluno)
);

-- ------------------------------------------------------------
-- t13_tipo_documento
-- ------------------------------------------------------------
CREATE TABLE t13_tipo_documento (
    id          INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    descricao   VARCHAR(100) NOT NULL   -- ex: 'BI', 'Certidão de Nascimento', 'Boletim'
);

-- ------------------------------------------------------------
-- t14_documentos
-- ------------------------------------------------------------
CREATE TABLE t14_documentos (
    id                  INT          PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    id_matricula        INT          NOT NULL,
    id_tipo_documento   INT          NOT NULL,
    nome                VARCHAR(255),
    data_expiracao      DATE,
    estado              BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_documentos_matricula
        FOREIGN KEY (id_matricula) REFERENCES t12_matricula (id),

    CONSTRAINT fk_documentos_tipo
        FOREIGN KEY (id_tipo_documento) REFERENCES t13_tipo_documento (id)
);

-- ------------------------------------------------------------
-- t15_notificacao
-- ------------------------------------------------------------
CREATE TABLE t15_notificacao (
    id                  INT                     PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    uuid_funcionario    UUID,                   -- NULL quando disparado automaticamente pelo sistema
    uuid_encarregado    UUID                    NOT NULL,
    sms                 TEXT,
    data_envio          TIMESTAMP               NOT NULL DEFAULT NOW(),
    estado              enum_estado_notificacao NOT NULL DEFAULT 'PENDENTE',

    CONSTRAINT fk_notificacao_funcionario
        FOREIGN KEY (uuid_funcionario) REFERENCES t02_funcionario (uuid_funcionario),  -- FK nullable

    CONSTRAINT fk_notificacao_encarregado
        FOREIGN KEY (uuid_encarregado) REFERENCES t07_encarregado (uuid_encarregado)
);