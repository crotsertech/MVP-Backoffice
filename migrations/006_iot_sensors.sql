-- Migration 006: IoT Sensor Tracking
-- Adds device registry, time-series readings, alert thresholds, and device type catalog.

-- IoT DEVICE TYPES (catalog of supported sensor types)
CREATE TABLE `iot_device_types` (
  `type_id` int(11) NOT NULL,
  `type_slug` varchar(50) NOT NULL COMMENT 'Machine-readable identifier, e.g. salt_monitor, tds_sensor',
  `type_name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `metrics` json DEFAULT NULL COMMENT 'Array of metric objects: [{name, unit, min, max, alert_threshold_low, alert_threshold_high}]',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- IoT DEVICES (registered sensors linked to customer + equipment)
CREATE TABLE `iot_devices` (
  `device_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `equipment_id` int(11) DEFAULT NULL COMMENT 'Linked equipment this sensor monitors',
  `type_id` int(11) NOT NULL,
  `device_name` varchar(150) NOT NULL COMMENT 'Human-readable name, e.g. "Kitchen Softener Salt Monitor"',
  `device_key` varchar(64) NOT NULL COMMENT 'API key for device authentication',
  `mac_address` varchar(20) DEFAULT NULL,
  `firmware_version` varchar(20) DEFAULT NULL,
  `status` enum('active','inactive','offline','error') NOT NULL DEFAULT 'active',
  `last_seen` datetime DEFAULT NULL COMMENT 'Timestamp of last telemetry upload',
  `last_reading_summary` json DEFAULT NULL COMMENT 'Cached last reading values for quick dashboard display',
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- IoT READINGS (time-series sensor data)
CREATE TABLE `iot_readings` (
  `reading_id` bigint(20) UNSIGNED NOT NULL,
  `device_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `metric_name` varchar(50) NOT NULL COMMENT 'e.g. salt_level, tds, ph, pressure, flow_rate',
  `value` decimal(12,4) NOT NULL,
  `unit` varchar(20) NOT NULL DEFAULT '' COMMENT 'e.g. percent, ppm, psi, gpm',
  `recorded_at` datetime NOT NULL COMMENT 'When the sensor took the reading',
  `server_received_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'When the server received the upload',
  `metadata` json DEFAULT NULL COMMENT 'Optional device-specific metadata (battery %, signal strength, etc.)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- IoT ALERT THRESHOLDS (rules for when to notify)
CREATE TABLE `iot_alert_rules` (
  `rule_id` int(11) NOT NULL,
  `device_id` int(11) NOT NULL,
  `metric_name` varchar(50) NOT NULL,
  `rule_name` varchar(150) NOT NULL COMMENT 'e.g. "Low Salt Warning"',
  `condition` enum('below','above','equals','below_or_equals','above_or_equals') NOT NULL DEFAULT 'below',
  `threshold_value` decimal(12,4) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `notification_channels` json DEFAULT NULL COMMENT '["push","email"] - where to send alerts',
  `cooldown_minutes` int(11) NOT NULL DEFAULT 60 COMMENT 'Minimum time between repeated alerts for same rule',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- IoT ALERT LOG (fired alerts)
CREATE TABLE `iot_alert_log` (
  `alert_id` int(11) NOT NULL,
  `device_id` int(11) NOT NULL,
  `rule_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `metric_name` varchar(50) NOT NULL,
  `triggered_value` decimal(12,4) NOT NULL,
  `threshold_value` decimal(12,4) NOT NULL,
  `condition` varchar(20) NOT NULL,
  `message` text DEFAULT NULL,
  `triggered_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `acknowledged_at` timestamp NULL DEFAULT NULL,
  `acknowledged_by` int(11) DEFAULT NULL,
  `notification_sent` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- INDEXES -------------------------------------------------------------------

ALTER TABLE `iot_device_types`
  ADD PRIMARY KEY (`type_id`),
  ADD UNIQUE KEY `type_slug` (`type_slug`);

ALTER TABLE `iot_devices`
  ADD PRIMARY KEY (`device_id`),
  ADD UNIQUE KEY `device_key` (`device_key`),
  ADD KEY `customer_id` (`customer_id`),
  ADD KEY `equipment_id` (`equipment_id`),
  ADD KEY `type_id` (`type_id`),
  ADD KEY `idx_devices_status` (`status`),
  ADD KEY `idx_devices_last_seen` (`last_seen`);

ALTER TABLE `iot_readings`
  ADD PRIMARY KEY (`reading_id`),
  ADD KEY `device_id` (`device_id`),
  ADD KEY `customer_id` (`customer_id`),
  ADD KEY `idx_readings_metric_time` (`metric_name`, `recorded_at`),
  ADD KEY `idx_readings_recorded_at` (`recorded_at`),
  ADD KEY `idx_readings_device_time` (`device_id`, `recorded_at`);

ALTER TABLE `iot_alert_rules`
  ADD PRIMARY KEY (`rule_id`),
  ADD KEY `device_id` (`device_id`),
  ADD KEY `idx_rules_enabled` (`enabled`);

ALTER TABLE `iot_alert_log`
  ADD PRIMARY KEY (`alert_id`),
  ADD KEY `device_id` (`device_id`),
  ADD KEY `rule_id` (`rule_id`),
  ADD KEY `customer_id` (`customer_id`),
  ADD KEY `idx_alerts_unacked` (`acknowledged_at`, `triggered_at`),
  ADD KEY `idx_alerts_triggered_at` (`triggered_at`);

-- AUTO INCREMENT ------------------------------------------------------------

ALTER TABLE `iot_device_types`
  MODIFY `type_id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `iot_devices`
  MODIFY `device_id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `iot_readings`
  MODIFY `reading_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE `iot_alert_rules`
  MODIFY `rule_id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `iot_alert_log`
  MODIFY `alert_id` int(11) NOT NULL AUTO_INCREMENT;

-- SEED DATA -----------------------------------------------------------------

INSERT INTO `iot_device_types` (`type_slug`, `type_name`, `description`, `metrics`) VALUES
('salt_monitor', 'Salt Level Monitor', 'Ultrasonic or load-cell sensor measuring salt level in water softener brine tank',
 '[{"name":"salt_level","unit":"percent","min":0,"max":100,"alert_threshold_low":20,"alert_threshold_high":null},{"name":"battery_percent","unit":"percent","min":0,"max":100,"alert_threshold_low":15,"alert_threshold_high":null}]'),
('tds_sensor', 'TDS Sensor', 'Total Dissolved Solids sensor for water quality monitoring',
 '[{"name":"tds","unit":"ppm","min":0,"max":2000,"alert_threshold_low":null,"alert_threshold_high":500},{"name":"temperature","unit":"celsius","min":0,"max":100,"alert_threshold_low":null,"alert_threshold_high":null}]'),
('ph_sensor', 'pH Sensor', 'Water pH level monitoring',
 '[{"name":"ph","unit":"pH","min":0,"max":14,"alert_threshold_low":6.5,"alert_threshold_high":8.5}]'),
('pressure_sensor', 'Pressure Monitor', 'Water pressure monitoring for system diagnostics',
 '[{"name":"pressure","unit":"psi","min":0,"max":150,"alert_threshold_low":30,"alert_threshold_high":80}]'),
('flow_meter', 'Flow Meter', 'Water flow rate monitoring',
 '[{"name":"flow_rate","unit":"gpm","min":0,"max":50,"alert_threshold_low":null,"alert_threshold_high":null},{"name":"total_gallons","unit":"gallons","min":0,"max":999999,"alert_threshold_low":null,"alert_threshold_high":null}]'),
('temp_humidity', 'Temperature & Humidity', 'Ambient conditions monitoring for equipment rooms',
 '[{"name":"temperature","unit":"celsius","min":-20,"max":60,"alert_threshold_low":0,"alert_threshold_high":40},{"name":"humidity","unit":"percent","min":0,"max":100,"alert_threshold_low":null,"alert_threshold_high":80}]');
