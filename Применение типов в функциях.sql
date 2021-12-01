

create or replace function get_patient_info_by_id(
    p_patient_id number
)
return lazorenko_al.t_patient
as
    v_patient lazorenko_al.t_patient;

begin

    select lazorenko_al.t_patient(
        patient_id => p.patient_id,
        born_date => p.born_date,
        sex_id => p.sex_id
    )
    into v_patient
    from lazorenko_al.patient p
    where p.patient_id = p_patient_id;

    return v_patient;

    exception
        when no_data_found then
        lazorenko_al.add_error_log(
    $$plsql_unit_owner||'.'||$$plsql_unit,
        '{"error":"' || sqlerrm
                  ||'","value":"' || p_patient_id
                  ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                  ||'"}'
        );

        dbms_output.put_line('данный пациент отсутствует в базе больницы');

   return v_patient;

end;

------------------------------------------------------------------------------------------------------------------------
--------------------------------------------Проверка работоспособности--------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--Проверка пола
create or replace function sex_check(
    p_patient_id in number,
    p_spec_id in number
)
return boolean
as
    v_sex number;
    v_patient lazorenko_al.t_patient;
    v_count number;

begin

    v_patient:=lazorenko_al.get_patient_info_by_id(p_patient_id);
    v_sex:=v_patient.sex_id;
    select count(*)
    into v_count
    from lazorenko_al.specialisation s
    where s.spec_id=p_spec_id
          and (s.sex_id=v_sex or s.sex_id is null);

    return v_count>0;

end;

--Проверка возраста
create or replace function check_age(
    p_patient_id in number,
    p_spec_id in number
)
return boolean
as
    v_patient lazorenko_al.t_patient;
    v_age number;
    v_count number;

begin
    v_patient:=lazorenko_al.get_patient_info_by_id(p_patient_id);
    v_age:=lazorenko_al.calculate_age_from_date(v_patient.born_date);
    select count(*)
    into v_count
    from lazorenko_al.specialisation s
    where s.spec_id = p_spec_id
          and (s.min_age <= v_age or s.min_age is null)
          and (s.max_age >= v_age or s.max_age is null);

    return v_count>0;

end;


--Использование
declare
    v_check number;
begin
    v_check:=sys.diutil.bool_to_int(lazorenko_al.check_age(
    9,2)); --ПРОВЕРКА ВОЗРАСТА

    dbms_output.put_line(v_check);

end;

declare
    v_check number;
begin
    v_check:=sys.diutil.bool_to_int(lazorenko_al.sex_check(
    9,5)); --ПРОВЕРКА ПОЛА

    dbms_output.put_line(v_check);

end;