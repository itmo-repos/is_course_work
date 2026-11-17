package ru.ifmo.is.backend.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.report.*;
import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import ru.ifmo.is.backend.entitiy.enums.ClimateParameter;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.function.Consumer;

@Repository
@RequiredArgsConstructor
public class ReportRepository {
    private final NamedParameterJdbcTemplate jdbc;

    private static final String OCCUPANCY = """
            SELECT c.id AS chamber_id, c.code, c.name, c.status::text,
                   count(p.id) AS total,
                   count(p.id) FILTER (WHERE b.id IS NULL) AS free,
                   count(p.id) FILTER (WHERE b.id IS NOT NULL AND b.status <> 'PLACED') AS reserved,
                   count(p.id) FILTER (WHERE b.status = 'PLACED') AS occupied,
                   count(p.id) FILTER (WHERE NOT p.is_serviceable) AS unserviceable,
                   count(p.id) FILTER (WHERE b.id IS NULL AND p.is_serviceable AND c.status = 'ACTIVE') AS available,
                   coalesce(round(100.0 * count(b.id) FILTER (WHERE b.status='PLACED')
                       / nullif(count(p.id),0),2),0) AS occupied_percent,
                   coalesce(round(100.0 * count(b.id) / nullif(count(p.id),0),2),0) AS assigned_percent
            FROM chamber c
            LEFT JOIN storage_place p ON p.chamber_id=c.id
            LEFT JOIN box b ON b.storage_place_id=p.id
            WHERE (CAST(:chamberId AS bigint) IS NULL OR c.id=:chamberId)
            GROUP BY c.id, c.code, c.name, c.status
            """;

    private static final String DEPOSITORS = """
            SELECT d.id AS depositor_id, d.legal_name, d.country_code, c.verified_at AS activated_at,
                   c.number AS contract_number, c.valid_from, c.valid_to,
                   (SELECT count(*) FROM batch b WHERE b.depositor_id=d.id) AS batch_count,
                   (SELECT count(*) FROM box x JOIN batch b ON b.id=x.batch_id
                       WHERE b.depositor_id=d.id AND x.storage_place_id IS NOT NULL
                         AND x.status <> 'PLACED') AS reserved_boxes,
                   (SELECT count(*) FROM box x JOIN batch b ON b.id=x.batch_id
                       WHERE b.depositor_id=d.id AND x.status='PLACED') AS placed_boxes,
                   (SELECT count(*) FROM sample s JOIN box x ON x.id=s.box_id
                       JOIN batch b ON b.id=x.batch_id WHERE b.depositor_id=d.id AND x.status='PLACED') AS stored_samples
            FROM depositor d
            LEFT JOIN LATERAL (
                SELECT number, verified_at, valid_from, valid_to FROM contract
                WHERE depositor_id=d.id AND status='VERIFIED'
                ORDER BY verified_at DESC NULLS LAST, id DESC LIMIT 1
            ) c ON true
            WHERE d.status='ACTIVE'
              AND (CAST(:depositorId AS bigint) IS NULL OR d.id=:depositorId)
              AND (CAST(:countryCode AS varchar) IS NULL OR d.country_code=:countryCode)
              AND (CAST(:from AS timestamp) IS NULL OR c.verified_at BETWEEN :from AND :to)
            """;

    private static final String SHIPMENTS = """
            WITH shipment_events AS (
                SELECT id AS event_id, batch_id, replace(action,'BATCH_','') AS event,
                       occurred_at, 'AUDIT' AS source
                FROM audit_event WHERE action IN ('BATCH_IN_TRANSIT','BATCH_ARRIVED')
                UNION ALL
                SELECT NULL::bigint, b.id, 'ARRIVED', b.arrived_at, 'BATCH'
                FROM batch b WHERE b.arrived_at IS NOT NULL AND NOT EXISTS (
                    SELECT 1 FROM audit_event e WHERE e.batch_id=b.id AND e.action='BATCH_ARRIVED')
            )
            SELECT e.event_id, b.id AS batch_id, b.number AS batch_number,
                   d.id AS depositor_id, d.legal_name AS depositor_name,
                   e.event, e.occurred_at, e.source,
                   (SELECT count(*) FROM box x WHERE x.batch_id=b.id) AS box_count
            FROM shipment_events e JOIN batch b ON b.id=e.batch_id JOIN depositor d ON d.id=b.depositor_id
            WHERE e.occurred_at BETWEEN :from AND :to
              AND (CAST(:depositorId AS bigint) IS NULL OR d.id=:depositorId)
              AND (CAST(:batchId AS bigint) IS NULL OR b.id=:batchId)
            """;

    private static final String WITHDRAWALS = """
            SELECT ws.id AS session_id, wr.id AS request_id, b.id AS batch_id, b.number AS batch_number,
                   d.id AS depositor_id, d.legal_name AS depositor_name, ws.curator_id,
                   ws.planned_date, ws.completed_at,
                   (SELECT count(*) FROM withdrawal_session_box x WHERE x.session_id=ws.id) AS box_count,
                   (SELECT count(*) FROM withdrawal_session_box x JOIN sample s ON s.box_id=x.box_id
                       WHERE x.session_id=ws.id) AS sample_count,
                   (SELECT coalesce(sum(s.seed_quantity),0) FROM withdrawal_session_box x
                       JOIN sample s ON s.box_id=x.box_id WHERE x.session_id=ws.id) AS seed_quantity
            FROM withdrawal_session ws JOIN withdrawal_request wr ON wr.id=ws.request_id
            JOIN batch b ON b.id=wr.batch_id JOIN depositor d ON d.id=b.depositor_id
            WHERE ws.status='COMPLETED' AND ws.completed_at BETWEEN :from AND :to
              AND (CAST(:depositorId AS bigint) IS NULL OR d.id=:depositorId)
              AND (CAST(:batchId AS bigint) IS NULL OR b.id=:batchId)
            """;

    private static final String INCIDENTS = """
            SELECT r.*, c.code AS chamber_code,
                CASE WHEN (r.temperature < r.min_temperature OR r.temperature > r.max_temperature)
                       AND (r.humidity < r.min_humidity OR r.humidity > r.max_humidity) THEN 'BOTH'
                     WHEN r.temperature < r.min_temperature OR r.temperature > r.max_temperature THEN 'TEMPERATURE'
                     ELSE 'HUMIDITY' END AS parameter
            FROM climate_reading r JOIN chamber c ON c.id=r.chamber_id
            WHERE r.measured_at BETWEEN :from AND :to
              AND (CAST(:chamberId AS bigint) IS NULL OR r.chamber_id=:chamberId)
              AND (r.temperature < r.min_temperature OR r.temperature > r.max_temperature
                   OR r.humidity < r.min_humidity OR r.humidity > r.max_humidity)
            """;

    private static final RowMapper<OccupancyReportRow> OCCUPANCY_ROW = (r,n) -> new OccupancyReportRow(
            r.getLong("chamber_id"), r.getString("code"), r.getString("name"), ChamberStatus.valueOf(r.getString("status")),
            r.getLong("total"), r.getLong("free"), r.getLong("reserved"), r.getLong("occupied"),
            r.getLong("unserviceable"), r.getLong("available"), r.getBigDecimal("occupied_percent"), r.getBigDecimal("assigned_percent"));
    private static final RowMapper<DepositorReportRow> DEPOSITOR_ROW = (r,n) -> new DepositorReportRow(
            r.getLong("depositor_id"), r.getString("legal_name"), r.getString("country_code"), time(r,"activated_at"),
            r.getString("contract_number"), r.getObject("valid_from", java.time.LocalDate.class),
            r.getObject("valid_to", java.time.LocalDate.class), r.getLong("batch_count"),
            r.getLong("reserved_boxes"), r.getLong("placed_boxes"), r.getLong("stored_samples"));
    private static final RowMapper<ShipmentReportRow> SHIPMENT_ROW = (r,n) -> new ShipmentReportRow(
            r.getObject("event_id", Long.class), r.getLong("batch_id"), r.getString("batch_number"),
            r.getLong("depositor_id"), r.getString("depositor_name"), r.getString("event"), time(r,"occurred_at"),
            r.getLong("box_count"), r.getString("source"));
    private static final RowMapper<WithdrawalReportRow> WITHDRAWAL_ROW = (r,n) -> new WithdrawalReportRow(
            r.getLong("session_id"), r.getLong("request_id"), r.getLong("batch_id"), r.getString("batch_number"),
            r.getLong("depositor_id"), r.getString("depositor_name"), r.getLong("curator_id"),
            r.getObject("planned_date", java.time.LocalDate.class), time(r,"completed_at"),
            r.getLong("box_count"), r.getLong("sample_count"), r.getLong("seed_quantity"));
    private static final RowMapper<ClimateIncidentReportRow> INCIDENT_ROW = (r,n) -> new ClimateIncidentReportRow(
            r.getLong("id"), r.getLong("chamber_id"), r.getString("chamber_code"), time(r,"measured_at"),
            r.getBigDecimal("temperature"), r.getBigDecimal("humidity"), r.getBigDecimal("min_temperature"),
            r.getBigDecimal("max_temperature"), r.getBigDecimal("min_humidity"), r.getBigDecimal("max_humidity"),
            ClimateParameter.valueOf(r.getString("parameter")));

    public PageView<OccupancyReportRow> occupancy(Long chamberId, int page, int size) {
        return page(OCCUPANCY,"code, chamber_id",params(null,null,null,null,chamberId,null),OCCUPANCY_ROW,page,size);
    }
    public void occupancy(Long chamberId, Consumer<OccupancyReportRow> consumer) {
        scan(OCCUPANCY,"code, chamber_id",params(null,null,null,null,chamberId,null),OCCUPANCY_ROW,consumer);
    }
    public PageView<DepositorReportRow> depositors(LocalDateTime from, LocalDateTime to, Long depositorId,
                                                   String countryCode, int page, int size) {
        return page(DEPOSITORS,"legal_name, depositor_id",params(from,to,depositorId,null,null,countryCode),DEPOSITOR_ROW,page,size);
    }
    public void depositors(LocalDateTime from, LocalDateTime to, Long depositorId,
                           String countryCode, Consumer<DepositorReportRow> consumer) {
        scan(DEPOSITORS,"legal_name, depositor_id",params(from,to,depositorId,null,null,countryCode),DEPOSITOR_ROW,consumer);
    }
    public PageView<ShipmentReportRow> shipments(LocalDateTime from, LocalDateTime to, Long depositorId,
                                                 Long batchId, int page, int size) {
        return page(SHIPMENTS,"occurred_at, batch_id, event_id",params(from,to,depositorId,batchId,null,null),SHIPMENT_ROW,page,size);
    }
    public void shipments(LocalDateTime from, LocalDateTime to, Long depositorId, Long batchId, Consumer<ShipmentReportRow> consumer) {
        scan(SHIPMENTS,"occurred_at, batch_id, event_id",params(from,to,depositorId,batchId,null,null),SHIPMENT_ROW,consumer);
    }
    public PageView<WithdrawalReportRow> withdrawals(LocalDateTime from, LocalDateTime to, Long depositorId,
                                                     Long batchId, int page, int size) {
        return page(WITHDRAWALS,"completed_at, session_id",params(from,to,depositorId,batchId,null,null),WITHDRAWAL_ROW,page,size);
    }
    public void withdrawals(LocalDateTime from, LocalDateTime to, Long depositorId, Long batchId, Consumer<WithdrawalReportRow> consumer) {
        scan(WITHDRAWALS,"completed_at, session_id",params(from,to,depositorId,batchId,null,null),WITHDRAWAL_ROW,consumer);
    }
    public PageView<ClimateIncidentReportRow> incidents(LocalDateTime from, LocalDateTime to, Long chamberId, int page, int size) {
        return page(INCIDENTS,"measured_at, id",params(from,to,null,null,chamberId,null),INCIDENT_ROW,page,size);
    }
    public void incidents(LocalDateTime from, LocalDateTime to, Long chamberId, Consumer<ClimateIncidentReportRow> consumer) {
        scan(INCIDENTS,"measured_at, id",params(from,to,null,null,chamberId,null),INCIDENT_ROW,consumer);
    }

    private <T> PageView<T> page(String sql, String order, MapSqlParameterSource params, RowMapper<T> mapper, int page, int size) {
        long total = jdbc.queryForObject("SELECT count(*) FROM (" + sql + ") report_rows",params,Long.class);
        params.addValue("limit",size).addValue("offset",(long)page*size);
        var rows = jdbc.query(sql + " ORDER BY " + order + " LIMIT :limit OFFSET :offset",params,mapper);
        return new PageView<>(rows,total,page,size);
    }
    private <T> void scan(String sql, String order, MapSqlParameterSource params, RowMapper<T> mapper, Consumer<T> consumer) {
        jdbc.query(sql + " ORDER BY " + order,params,(RowCallbackHandler) r -> consumer.accept(mapper.mapRow(r,0)));
    }
    private MapSqlParameterSource params(LocalDateTime from, LocalDateTime to, Long depositorId,
                                         Long batchId, Long chamberId, String countryCode) {
        return new MapSqlParameterSource().addValue("from",from).addValue("to",to).addValue("depositorId",depositorId)
                .addValue("batchId",batchId).addValue("chamberId",chamberId).addValue("countryCode",countryCode);
    }
    private static OffsetDateTime time(ResultSet result, String column) throws SQLException {
        var timestamp = result.getTimestamp(column);
        return timestamp == null ? null : timestamp.toLocalDateTime().atOffset(ZoneOffset.UTC);
    }
}
