-- Migration 005: Estimates/Quotes and Service Contracts
-- Adds estimate/quote workflow and recurring service contract functionality.

-- ESTIMATES (quotes sent to customers before work is approved)
CREATE TABLE `estimates` (
  `estimate_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `appointment_id` int(11) DEFAULT NULL COMMENT 'Linked appointment if estimate came from a service call',
  `contract_id` int(11) DEFAULT NULL COMMENT 'Linked contract if estimate is for contract-related work',
  `estimate_number` varchar(20) NOT NULL,
  `status` enum('draft','sent','approved','rejected','expired','converted') NOT NULL DEFAULT 'draft',
  `issue_date` date NOT NULL,
  `expiry_date` date DEFAULT NULL,
  `subtotal` decimal(10,2) NOT NULL DEFAULT 0.00,
  `taxable_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `tax_rate` decimal(5,4) NOT NULL DEFAULT 0.0000,
  `tax_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `notes` text DEFAULT NULL,
  `customer_response_notes` text DEFAULT NULL COMMENT 'Customer notes when approving/rejecting',
  `created_by` int(11) NOT NULL,
  `converted_invoice_id` int(11) DEFAULT NULL COMMENT 'Invoice created when estimate was approved/converted',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ESTIMATE LINE ITEMS (mirrors invoice_lines structure)
CREATE TABLE `estimate_lines` (
  `line_id` int(11) NOT NULL,
  `estimate_id` int(11) NOT NULL,
  `part_id` int(11) DEFAULT NULL,
  `line_type` enum('labor','service_call','parts','filter','equipment','salt','warranty','discount','custom') NOT NULL DEFAULT 'custom',
  `line_name` varchar(255) DEFAULT NULL,
  `description` varchar(255) NOT NULL,
  `quantity` decimal(8,2) NOT NULL DEFAULT 1.00,
  `unit_price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `is_taxable` tinyint(1) NOT NULL DEFAULT 0,
  `h2o2_prorate` decimal(5,2) DEFAULT NULL,
  `discount_note` varchar(255) DEFAULT NULL,
  `line_total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `sort_order` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ESTIMATE COUNTER (for numbering, mirrors invoice_counter)
CREATE TABLE `estimate_counter` (
  `id` int(11) NOT NULL,
  `year` int(11) NOT NULL,
  `sequence` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- SERVICE CONTRACTS (recurring service agreements)
CREATE TABLE `service_contracts` (
  `contract_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `contract_number` varchar(20) NOT NULL,
  `name` varchar(255) NOT NULL COMMENT 'Descriptive name, e.g. "Annual Water Softener Maintenance"',
  `status` enum('draft','active','expired','cancelled') NOT NULL DEFAULT 'draft',
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL COMMENT 'NULL = ongoing / auto-renewing',
  `auto_renew` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 = automatically renew for another term when end_date is reached',
  `renew_term_months` int(11) DEFAULT 12 COMMENT 'How many months to add on auto-renew',
  `frequency` enum('monthly','quarterly','semi_annual','annual','custom') NOT NULL DEFAULT 'annual',
  `custom_interval_days` int(11) DEFAULT NULL COMMENT 'Used when frequency = custom',
  `visits_per_cycle` int(11) NOT NULL DEFAULT 1 COMMENT 'How many service visits per billing cycle',
  `billing_cycle` enum('monthly','quarterly','semi_annual','annual','per_visit') NOT NULL DEFAULT 'annual',
  `cycle_price` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Price per billing cycle',
  `per_visit_price` decimal(10,2) DEFAULT NULL COMMENT 'Override price per individual visit (if billing = per_visit)',
  `discount_percent` decimal(5,2) DEFAULT NULL COMMENT 'Discount % applied to standard service rates',
  `notes` text DEFAULT NULL,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- CONTRACT EQUIPMENT (which equipment items are covered by a contract)
CREATE TABLE `contract_equipment` (
  `id` int(11) NOT NULL,
  `contract_id` int(11) NOT NULL,
  `equipment_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- CONTRACT SERVICE TYPES (which service types are included in the contract)
CREATE TABLE `contract_service_types` (
  `id` int(11) NOT NULL,
  `contract_id` int(11) NOT NULL,
  `service_type_id` int(11) NOT NULL,
  `included_visits` int(11) NOT NULL DEFAULT 1 COMMENT 'How many of this service type per cycle'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- CONTRACT INVOICE SCHEDULE (tracks which invoices were generated for which contract cycle)
CREATE TABLE `contract_invoice_log` (
  `id` int(11) NOT NULL,
  `contract_id` int(11) NOT NULL,
  `invoice_id` int(11) DEFAULT NULL,
  `cycle_start` date NOT NULL,
  `cycle_end` date NOT NULL,
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- CONTRACT APPOINTMENT LOG (tracks appointments generated from contracts)
CREATE TABLE `contract_appointment_log` (
  `id` int(11) NOT NULL,
  `contract_id` int(11) NOT NULL,
  `appointment_id` int(11) NOT NULL,
  `scheduled_date` date NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- INDEXES -------------------------------------------------------------------

ALTER TABLE `estimates`
  ADD PRIMARY KEY (`estimate_id`),
  ADD UNIQUE KEY `estimate_number` (`estimate_number`),
  ADD KEY `customer_id` (`customer_id`),
  ADD KEY `appointment_id` (`appointment_id`),
  ADD KEY `contract_id` (`contract_id`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `idx_estimates_status` (`status`),
  ADD KEY `idx_estimates_expiry` (`expiry_date`);

ALTER TABLE `estimate_lines`
  ADD PRIMARY KEY (`line_id`),
  ADD KEY `estimate_id` (`estimate_id`);

ALTER TABLE `estimate_counter`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `year_seq` (`year`);

ALTER TABLE `service_contracts`
  ADD PRIMARY KEY (`contract_id`),
  ADD UNIQUE KEY `contract_number` (`contract_number`),
  ADD KEY `customer_id` (`customer_id`),
  ADD KEY `idx_contracts_status` (`status`),
  ADD KEY `idx_contracts_end_date` (`end_date`),
  ADD KEY `created_by` (`created_by`);

ALTER TABLE `contract_equipment`
  ADD PRIMARY KEY (`id`),
  ADD KEY `contract_id` (`contract_id`),
  ADD KEY `equipment_id` (`equipment_id`);

ALTER TABLE `contract_service_types`
  ADD PRIMARY KEY (`id`),
  ADD KEY `contract_id` (`contract_id`),
  ADD KEY `service_type_id` (`service_type_id`);

ALTER TABLE `contract_invoice_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `contract_id` (`contract_id`),
  ADD KEY `invoice_id` (`invoice_id`);

ALTER TABLE `contract_appointment_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `contract_id` (`contract_id`),
  ADD KEY `appointment_id` (`appointment_id`);

-- AUTO INCREMENT ------------------------------------------------------------

ALTER TABLE `estimates`
  MODIFY `estimate_id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `estimate_lines`
  MODIFY `line_id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `estimate_counter`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `service_contracts`
  MODIFY `contract_id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `contract_equipment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `contract_service_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `contract_invoice_log`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `contract_appointment_log`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

-- SEED: estimate counter for current year -----------------------------------
INSERT INTO `estimate_counter` (`id`, `year`, `sequence`) VALUES (1, YEAR(CURDATE()), 0);
