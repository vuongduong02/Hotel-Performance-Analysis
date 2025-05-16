# 1. Tỉ lệ lấp đầy phòng theo tháng ?
WITH RECURSIVE stay_nights AS (
	SELECT 
		booking_id,
        check_in,
        check_out,
        status
	FROM bookings
    WHERE status = 'Confirmed'
    
    UNION ALL
    
	SELECT 
		s.booking_id,
        DATE_ADD(s.check_in, INTERVAL 1 DAY),
        s.check_out,
        s.status
	FROM stay_nights s
    WHERE DATE_ADD(s.check_in, INTERVAL 1 DAY) < s.check_out
    AND status = 'Confirmed'
)
Select
	DATE_FORMAT(s.check_in, '%Y-%m') AS month,
    COUNT(s.check_in) * 100 / (DAY(LAST_DAY(MIN(s.check_in))) * (SELECT COUNT(*) FROM rooms)) AS occupancy_rate -- Số ngày trong tháng x Tổng số phòng = Số đêm phòng có sẵn
FROM stay_nights s
GROUP BY month
ORDER BY month
;

# 2. Đếm số lượng phòng mỗi loại
SELECT 
	room_type,
    COUNT(*) AS room_type_count
FROM rooms
GROUP BY room_type
;

# 3. Phòng nào có tỷ lệ lấp đầy thấp nhất?
WITH RECURSIVE stay_nights AS (
	SELECT 
		b.booking_id,
        r.room_id,
        r.room_type,
        r.room_number,
		b.check_in,
        b.check_out,
        b.status
	FROM bookings b
    JOIN rooms r
    ON b.room_id = r.room_id
    WHERE b.status = 'Confirmed'
    
    UNION ALL
    
	SELECT 
		s.booking_id,
        s.room_id,
        s.room_type,
        s.room_number,
		DATE_ADD(s.check_in, INTERVAL 1 DAY),
        s.check_out,
        s.status
	FROM stay_nights s
    WHERE s.status = 'Confirmed'
    AND DATE_ADD(s.check_in, INTERVAL 1 DAY) < s.check_out
), 
room_occupancy AS (
	SELECT
		DATE_FORMAT(s.check_in, '%Y-%m') AS month,
		s.room_id,
        s.room_number,
		s.room_type,
        COUNT(s.check_in) AS stay_duration,
		COUNT(s.check_in)  * 100.0 / (DAY(LAST_DAY(MIN(s.check_in)))) AS occupancy_rate,
		DENSE_RANK() OVER (PARTITION BY DATE_FORMAT(s.check_in, '%Y-%m') ORDER BY COUNT(s.check_in)  * 100.0 / (DAY(LAST_DAY(MIN(s.check_in))))) AS occupancy_rate_rank
	FROM stay_nights s
	GROUP BY month, s.room_id, s.room_number, s.room_type
)
SELECT 
	ro.month,
    ro.room_id,
    ro.room_number,
    ro.room_type,
    ro.stay_duration,
    ro.occupancy_rate
FROM room_occupancy ro
WHERE occupancy_rate_rank = 1
ORDER BY ro.month
;

# 4. Loại phòng nào được đặt ít nhất mỗi tháng ?
WITH cte AS (
	SELECT 
		DATE_FORMAT(b.created_at, '%Y-%m') AS month,
		r.room_type,
		COUNT(*) AS booking_times,
		DENSE_RANK() OVER(PARTITION BY DATE_FORMAT(b.created_at, '%Y-%m') ORDER BY COUNT(*)) AS booking_times_rank
	FROM bookings b
	LEFT JOIN rooms r
	ON b.room_id = r.room_id
	WHERE b.status = 'Confirmed'
	GROUP BY month,  r.room_type
)
SELECT 
	month,
	room_type,
	booking_times
FROM cte
WHERE booking_times_rank = 1
;


# 5. Số lượt đặt phòng theo tháng ?
SELECT 
    DATE_FORMAT(check_in, '%Y-%m') AS month,
    COUNT(*) AS bookings_count
FROM hotel_booking.bookings
WHERE status = 'Confirmed'
GROUP BY month
ORDER BY month
;

# 6. Phòng nào có doanh thu cao nhất ?
WITH customer_service_usage AS (
	SELECT 
		booking_id,
        SUM(total_price) AS adding_service_price
    FROM service_usage
    GROUP BY booking_id
)
SELECT
    b.room_id,
    r.room_number,
    r.room_type,
    SUM(r.price_per_night * DATEDIFF(b.check_out, b.check_in) + csu.adding_service_price) AS revenue
FROM bookings b
LEFT JOIN rooms r
ON b.room_id = r.room_id
LEFT JOIN customer_service_usage csu
ON b.booking_id = csu.booking_id
WHERE b.status = 'Confirmed'
GROUP BY b.room_id, r.room_number, r.room_type
ORDER BY revenue DESC 
LIMIT 1
; 	

# 7. Dịch vụ nào được sử dụng nhiều nhất?
SELECT 
	svu.service_id,
    sv.service_name,
	COUNT(*) AS usage_times
FROM service_usage svu
LEFT JOIN services sv
ON svu.service_id = sv.service_id
GROUP BY svu.service_id, sv.service_name
ORDER BY usage_times DESC
LIMIT 1;

# 8. Dịch vụ nào mang lại doanh thu cao nhất?
SELECT 
	svu.service_id,
    sv.service_name,
	SUM(svu.total_price) AS service_revenue
FROM service_usage svu
LEFT JOIN services sv
ON svu.service_id = sv.service_id
GROUP BY svu.service_id, sv.service_name
ORDER BY service_revenue DESC
LIMIT 1;

# 9. Có bao nhiêu khách quay lại?
WITH customer_booking_times AS(
	SELECT 
		c.customer_id,
		COUNT(c.customer_id) AS booking_times
	FROM bookings b
	LEFT JOIN customers c
	ON b.customer_id = c.customer_id
	WHERE status = 'Confirmed'
	GROUP BY customer_id
)
SELECT 
	booking_times,
    COUNT(*) AS customer
FROM customer_booking_times
WHERE booking_times > 1
GROUP BY booking_times
ORDER BY booking_times
;

# 10. Khách hàng nào có số lần đặt phòng nhiều nhất ?
WITH customer_booking_times AS(
	SELECT 
		c.customer_id,
		COUNT(c.customer_id) AS booking_times
	FROM bookings b
	LEFT JOIN customers c
	ON b.customer_id = c.customer_id
	WHERE status = 'Confirmed'
	GROUP BY customer_id
)
SELECT 
	cbt.customer_id,
    c.full_name
FROM customer_booking_times cbt
LEFT JOIN customers c
ON cbt.customer_id = c.customer_id
WHERE cbt.booking_times = (SELECT MAX(booking_times) FROM customer_booking_times)
;

# 11. Tỷ lệ hủy đặt phòng trung bình?
SELECT 
	COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*) AS cancellation_rate
FROM bookings b
WHERE status <> "Pending"
;

# 12. Tình trạng huỷ đặt phòng theo tháng
SELECT 
	DATE_FORMAT(b.created_at, '%Y-%m') AS month,
	COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) AS cancellation_count,
    COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*) AS cancellation_rate
FROM bookings b
WHERE status <> "Pending"
GROUP BY month
ORDER BY month 
;