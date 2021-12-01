--ЗАПРОС 1
--создание типов
create or replace type lazorenko_al.t_city_with_regions as object(
    city_id number,
    names varchar2(100),
    region_id number,
    name varchar2(100)
);

create or replace type lazorenko_al.t_arr_city_with_regions as table of lazorenko_al.t_city_with_regions;


--запрос
create or replace function lazorenko_al.get_cities_regions_with_own_type(
    p_region_id in number default null
)
return lazorenko_al.t_arr_city_with_regions
as
    arr_city_with_regions lazorenko_al.t_arr_city_with_regions:=lazorenko_al.t_arr_city_with_regions();

begin

    select lazorenko_al.t_city_with_regions(
        city_id => c.city_id,
        names => c.names,
        region_id => c.region_id,
        name =>r.name)
    bulk collect into arr_city_with_regions

    from lazorenko_al.city c
    inner join lazorenko_al.region r on c.region_id=r.region_id

    where p_region_id=c.region_id
          or p_region_id is null;

return arr_city_with_regions;

end;

--вывод
declare
    v_arr_city_with_regions lazorenko_al.t_arr_city_with_regions := lazorenko_al.t_arr_city_with_regions();

begin

    v_arr_city_with_regions := lazorenko_al.get_cities_regions_with_own_type(1);

    if v_arr_city_with_regions.count>0 then
    for i in v_arr_city_with_regions.first..v_arr_city_with_regions.last
    loop
    declare
        v_item lazorenko_al.t_city_with_regions :=v_arr_city_with_regions(i);
    begin
        dbms_output.put_line(v_item.names || v_item.name);
    end;
    end loop;
    end if;

end;

--ЗАПРОС 2

--создание типов
create or replace type lazorenko_al.t_specs as object(
    name varchar2(100)
);

create or replace type lazorenko_al.t_arr_specs as table of lazorenko_al.t_specs;

--запрос
create or replace function lazorenko_al.get_specs_with_own_types(
    p_doctor_id in number default null,
    p_hospital_id in number default null
)
return lazorenko_al.t_arr_specs
as
    arr_specs lazorenko_al.t_arr_specs :=lazorenko_al.t_arr_specs();

begin

    select lazorenko_al.t_specs(
        name => s.name)
    bulk collect into arr_specs
    from specialisation s inner join doctor_spec using(spec_id)
    inner join doctor d using(doctor_id)
    inner join hospital h using(hospital_id)

    where s.delete_from_the_sys is null and d.dismiss_date is null and h.delete_from_the_sys is null
          and (p_hospital_id=hospital_id or p_hospital_id is null)
          and (p_doctor_id=doctor_id or p_doctor_id is null);

return arr_specs;

end;

--вывод
declare
    v_arr_specs lazorenko_al.t_arr_specs := lazorenko_al.t_arr_specs();

begin

    v_arr_specs := lazorenko_al.get_specs_with_own_types(null, null);

    if v_arr_specs.count>0 then
    for i in v_arr_specs.first..v_arr_specs.last
    loop
    declare
        v_item lazorenko_al.t_specs :=v_arr_specs(i);
    begin
        dbms_output.put_line(v_item.name);
    end;
    end loop;
    end if;

end;


--ЗАПРОС 3

--создание типов
create or replace type lazorenko_al.t_hospital_info as object(
    hname varchar2(100),
    aname varchar2(100),
    doctor_id number,
    ownership_type varchar2(100),
    end_time varchar2(100));

create or replace type lazorenko_al.t_arr_hospital_info as table of lazorenko_al.t_hospital_info;


--запрос

create or replace function lazorenko_al.get_doctors_specs_with_own_types(
    p_spec_id number
)
return lazorenko_al.t_arr_hospital_info
as
    arr_hospital_info lazorenko_al.t_arr_hospital_info:=lazorenko_al.t_arr_hospital_info();
begin
    select lazorenko_al.t_hospital_info(
        hname => h.name,
        aname => a.name,
        doctor_id => count(d.doctor_id),
        ownership_type =>
    case
        when o.ownership_type_id=1 then 'частная'
        when o.ownership_type_id=2 then 'государственная'
        end,
        end_time =>
    case
        when w.end_time is null then ' - '
        else w.end_time
        end)
    bulk collect into arr_hospital_info
    from hospital h left join work_time w on h.hospital_id=w.hospital_id
    inner join ownership_type o on h.ownership_type_id=o.ownership_type_id
    inner join doctor d on d.hospital_id=h.hospital_id
    inner join doctor_spec ds on d.doctor_id=ds.doctor_id
    inner join available a on h.availability_id=a.availability_id

    where (spec_id=p_spec_id or p_spec_id is null) and h.delete_from_the_sys is null
           and w.day=to_char(sysdate, 'd')

    group by h.name, a.name, o.ownership_type_id, w.end_time
    order by case
             when o.ownership_type_id=1 then 1
             else 0 end desc, count(d.doctor_id) desc,
             case
             when w.end_time>TO_CHAR(sysdate, 'hh24:mi:ss') then 1
             else 0
             end desc;

return arr_hospital_info;

end;

--вывод
declare
    v_arr_hospital_info lazorenko_al.t_arr_hospital_info := lazorenko_al.t_arr_hospital_info();

begin

    v_arr_hospital_info := lazorenko_al.get_doctors_specs_with_own_types(2);

    if v_arr_hospital_info.count>0 then
    for i in v_arr_hospital_info.first..v_arr_hospital_info.last
    loop
    declare
        v_item lazorenko_al.t_hospital_info :=v_arr_hospital_info(i);
    begin
        dbms_output.put_line(v_item.hname || ' '|| v_item.aname || ' '|| v_item.doctor_id
                                 || ' '|| v_item.ownership_type || ' '|| v_item.end_time);
    end;
    end loop;
    end if;

end;



--ЗАПРОС 4

--создание типов
create or replace type lazorenko_al.t_doctors_detailed as object(
    dname varchar(100),
    sname varchar(100),
    qualification number);

create or replace type lazorenko_al.t_arr_doctors_detailed as table of lazorenko_al.t_doctors_detailed;

--запрос
create or replace function lazorenko_al.get_doctor_with_own_types(
    p_hospital_id in number,
    p_zone_id in number
)
return lazorenko_al.t_arr_doctors_detailed
as
    arr_doctors_detailed lazorenko_al.t_arr_doctors_detailed:=lazorenko_al.t_arr_doctors_detailed();

begin

    select lazorenko_al.t_doctors_detailed(
        dname => d.name,
        sname => s.name,
        qualification => di.qualification)
    bulk collect into arr_doctors_detailed
    from doctor d inner join doctor_spec using(doctor_id)
    inner join specialisation s using(spec_id)
    inner join doctors_info di using(doctor_id)
    inner join hospital using(hospital_id)

    where (hospital_id=p_hospital_id or p_hospital_id is null) and d.dismiss_date is null

    order by di.qualification desc,
             case
             when d.zone_id=p_zone_id then 1
             else 0 end desc;

return arr_doctors_detailed;

end;

--вывод
declare
    v_arr_doctors_detailed lazorenko_al.t_arr_doctors_detailed := lazorenko_al.t_arr_doctors_detailed();

begin

    v_arr_doctors_detailed := lazorenko_al.get_doctor_with_own_types(6, 2);

    if v_arr_doctors_detailed.count>0 then
    for i in v_arr_doctors_detailed.first..v_arr_doctors_detailed.last
    loop
    declare
        v_item lazorenko_al.t_doctors_detailed :=v_arr_doctors_detailed(i);
    begin
        dbms_output.put_line(v_item.dname || ' '|| v_item.sname || ' '|| v_item.qualification);
    end;
    end loop;
    end if;

end;


--ЗАПРОС 5

--создание типов
create or replace type lazorenko_al.t_ticket as object(
    ticket_id number,
    name varchar2(100),
    appointment_beg varchar2(50),
    appointment_end varchar2(50));

create or replace type lazorenko_al.t_arr_ticket as table of lazorenko_al.t_ticket;

--запрос

create or replace function lazorenko_al.get_ticket_with_own_types(
    p_doctor_id number
)
return lazorenko_al.t_arr_ticket
as
    arr_ticket lazorenko_al.t_arr_ticket:=lazorenko_al.t_arr_ticket();

begin

    select lazorenko_al.t_ticket(
        ticket_id => t.ticket_id,
        name => d.name,
        appointment_beg => t.appointment_beg,
        appointment_end => t.appointment_end)
    bulk collect into arr_ticket
    from ticket t right join doctor d using(doctor_id)
    where (doctor_id=p_doctor_id or p_doctor_id is null) and t.appointment_beg>to_char(sysdate, 'yyyy-mm-dd hh24:mi:ss')
    order by t.appointment_beg;

return arr_ticket;

end;


--вывод
declare
    v_arr_ticket lazorenko_al.t_arr_ticket := lazorenko_al.t_arr_ticket();

begin

    v_arr_ticket := lazorenko_al.get_ticket_with_own_types(3);

    if v_arr_ticket.count>0 then
    for i in v_arr_ticket.first..v_arr_ticket.last
    loop
    declare
        v_item lazorenko_al.t_ticket :=v_arr_ticket(i);
    begin
        dbms_output.put_line(v_item.ticket_id || ' '|| v_item.name || ' '|| v_item.appointment_beg || ' '|| v_item.appointment_end);
    end;
    end loop;
    end if;

end;

--ЗАПРОС 6

--создание типов
create or replace type lazorenko_al.t_records as object(
    last_name varchar2(100),
    first_name varchar2(100),
    petronymic varchar2(100),
    name varchar2(100),
    rname varchar2(50),
    appointment_beg varchar2(50),
    appointment_end varchar2(50));

create or replace type lazorenko_al.t_arr_records as table of lazorenko_al.t_records;

--запрос
create or replace function lazorenko_al.get_records_with_own_types(
    p_patient_id in number default null,
    p_record_stat_id in number default null
)
return lazorenko_al.t_arr_records
as
    arr_records lazorenko_al.t_arr_records:=lazorenko_al.t_arr_records();

begin

    select lazorenko_al.t_records(
        last_name => last_name,
        first_name => first_name,
        petronymic => petronymic,
        name => d.name,
        rname => record_status.name,
        appointment_beg => appointment_beg,
        appointment_end => appointment_end)
    bulk collect into arr_records
    from lazorenko_al.patient p left join lazorenko_al.records using(patient_id)
    inner join record_status using(record_stat_id)
    inner join ticket using(ticket_id)
    inner join lazorenko_al.doctor d using(doctor_id)

    where (patient_id=p_patient_id or p_patient_id is null) and (record_stat_id=p_record_stat_id or p_record_stat_id is null);

return arr_records;
end;

--вывод
declare
    v_arr_records lazorenko_al.t_arr_records := lazorenko_al.t_arr_records();

begin

    v_arr_records := lazorenko_al.get_records_with_own_types(1, 3);

    if v_arr_records.count>0 then
    for i in v_arr_records.first..v_arr_records.last
    loop
    declare
        v_item lazorenko_al.t_records :=v_arr_records(i);
    begin
        dbms_output.put_line(v_item.last_name || ' '|| v_item.first_name || ' '|| v_item.petronymic || ' '|| v_item.name || ' '|| v_item.rname || ' '|| v_item.appointment_beg || ' '|| v_item.appointment_end);
    end;
    end loop;
    end if;

end;