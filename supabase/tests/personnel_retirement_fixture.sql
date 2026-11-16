-- Committed legacy records, only in the disposable test DB before migration 015.
\set ON_ERROR_STOP on
insert into public.parking_reports(id,lot_id,reported_by,plate,description,status,assigned_to) values
 ('68000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000001',
 '14000000-0000-0000-0000-000000000001','43A94111','Legacy assigned report','assigned','14000000-0000-0000-0000-000000000003');
insert into public.notifications(user_id,title,body) values
 ('14000000-0000-0000-0000-000000000003','Báo cáo cần xử lý','Legacy personnel assignment');
insert into public.operation_receipts(actor_id,operation_id,kind,payload,result) values
 ('14000000-0000-0000-0000-000000000004','78000000-0000-0000-0000-000000000001','report.assign',
 '{"staff_id":"14000000-0000-0000-0000-000000000003"}',
 '{"id":"68000000-0000-0000-0000-000000000001","assigned_to":"14000000-0000-0000-0000-000000000003"}');
