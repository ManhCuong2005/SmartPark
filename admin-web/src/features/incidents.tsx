import { useMemo, useState } from "react";
import { Button, Empty, PageHeading, Panel } from "../components/ui";
import { useAdmin } from "../data/store";
import type { Incident } from "../data/models";
const labels: Record<string,string> = { wrong_slot:"Xe đỗ sai ô", ticket_mismatch:"Vé không khớp", vehicle_damage:"Hư hỏng phương tiện", equipment:"Thiết bị", safety:"An toàn / an ninh", other:"Khác" };
const states: Record<Incident["status"],string> = { open:"Mới", in_progress:"Đang xử lý", resolved:"Đã xử lý" };
export function IncidentsPage() {
 const { data, command, online } = useAdmin();
 const [filter,setFilter] = useState("all"), [selected,setSelected] = useState<Incident|null>(null), [resolution,setResolution] = useState(""), [busy,setBusy] = useState(false);
 const rows = useMemo(()=>data.incidents.filter(i=>filter==="all"||i.status===filter),[data.incidents,filter]);
 async function update(i: Incident,status: Incident["status"]) { setBusy(true); const ok=await command("update_incident",{p_id:i.id,p_status:status,p_resolution:resolution}); setBusy(false); if(ok){setSelected(null);setResolution("");} }
 return <>
  <PageHeading title="Sự cố tại bãi" subtitle={`${data.incidents.filter(i=>i.status!=="resolved").length} sự cố cần theo dõi · Cập nhật theo Realtime và đồng bộ định kỳ`} />
  <div className="metrics three incident-metrics"><Panel><strong>{data.incidents.filter(i=>i.status==="open").length}</strong><p>Sự cố mới</p></Panel><Panel><strong>{data.incidents.filter(i=>i.status==="in_progress").length}</strong><p>Đang xử lý</p></Panel><Panel><strong>{data.incidents.filter(i=>i.status==="resolved").length}</strong><p>Đã xử lý</p></Panel></div>
  <label>Lọc trạng thái <select value={filter} onChange={e=>setFilter(e.target.value)}><option value="all">Tất cả</option><option value="open">Mới</option><option value="in_progress">Đang xử lý</option><option value="resolved">Đã xử lý</option></select></label>
  {!online&&<p role="status">Mất kết nối Supabase. Dữ liệu hiển thị là lần tải gần nhất.</p>}
  <Panel>{rows.length? <div className="table-scroll"><table><thead><tr><th>Thời gian</th><th>Bãi</th><th>Loại</th><th>Nhân viên</th><th>Mô tả</th><th>Trạng thái</th><th></th></tr></thead><tbody>{rows.map(i=><tr key={i.id}><td>{new Date(i.createdAt).toLocaleString("vi-VN")}</td><td>{data.lots.find(l=>l.id===i.lotId)?.name??"—"}</td><td>{labels[i.category]??i.category}</td><td>{i.reporter}</td><td>{i.description}{i.resolution&&<p><b>Cách xử lý:</b> {i.resolution}</p>}</td><td>{states[i.status]}</td><td><Button secondary onClick={()=>{setSelected(i);setResolution(i.resolution);}}>Cập nhật</Button></td></tr>)}</tbody></table></div>:<Empty message="Chưa có báo cáo sự cố."/>}</Panel>
  {selected&&<div className="incident-dialog-backdrop" role="presentation"><section className="panel incident-dialog" role="dialog" aria-modal="true" aria-labelledby="incident-title"><h2 id="incident-title">Cập nhật sự cố</h2><p>{labels[selected.category]} · {selected.description}</p><label>Trạng thái<select value={selected.status} onChange={e=>setSelected({...selected,status:e.target.value as Incident["status"]})}><option value="open">Mới</option><option value="in_progress">Đang xử lý</option><option value="resolved">Đã xử lý</option></select></label>{selected.status==="resolved"&&<label>Cách xử lý<textarea minLength={3} required value={resolution} onChange={e=>setResolution(e.target.value)} /></label>}<div className="dialog-actions"><Button secondary onClick={()=>setSelected(null)}>Đóng</Button><Button disabled={busy||!online||(selected.status==="resolved"&&resolution.trim().length<3)} onClick={()=>void update(selected,selected.status)}>{busy?"Đang lưu…":"Lưu cập nhật"}</Button></div></section></div>}
 </>;
}
