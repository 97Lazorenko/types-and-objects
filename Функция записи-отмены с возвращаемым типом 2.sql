--ССЗДАНИЕ ТИПА, ВОЗВРАЩАЕМОГО ФУНКЦИЯМИ ЗАПИСИ И ОТМЕНЫ
create or replace type lazorenko_al.t_result as object(
    result_value number);

alter type lazorenko_al.t_result
add constructor function t_result(
    result_value number)
return self as result
cascade;

create or replace type body lazorenko_al.t_result
as
    constructor function t_result(
        result_value number
    )
    return self as result
    as
    begin
        self.result_value:= result_value;

        return;
    end;
end;



--ПАКЕТ С ФУНКЦИЯМИ ЗАПИСИ И ОТМЕНЫ ЗАПИСИ С ОТЛОВОМ ОШИЮОК И ЛОГИРОВАНИЕМ
create or replace package lazorenko_al.pkg_write_or_cancel
as
    c_record_or_ticket_stat_first constant number := 1;
                                                          --КОНСТАНТЫ БУДУТ ИСПОЛЬЗОВАНЫ В ФУНКЦИЯХ ЗАПИСИ И ОТМЕНЫ
    c_record_or_ticket_stat_second constant number := 2;

    v_result lazorenko_al.t_result;

    function cancel_record(
    p_ticket_id in number)
    return lazorenko_al.t_result;

    function write_to_records(
    p_patient_id in number,
    p_ticket_id in number,
    p_need_handle boolean)
    return lazorenko_al.t_result;
end;


create or replace package body lazorenko_al.pkg_write_or_cancel
as
    function write_to_records(
         p_patient_id in number,
         p_ticket_id in number,
         p_need_handle boolean
    )
    return lazorenko_al.t_result as
        v_result lazorenko_al.t_result;

        attempt_to_insert_null_into_not_null exception;
        pragma exception_init (attempt_to_insert_null_into_not_null, -01400);

    begin
        if (p_need_handle) then
            begin
                insert into lazorenko_al.records(record_id, record_stat_id, patient_id, ticket_id)
                values (default, lazorenko_al.pkg_write_or_cancel.c_record_or_ticket_stat_first, p_patient_id, p_ticket_id);

                update lazorenko_al.ticket t set t.ticket_stat_id=lazorenko_al.pkg_write_or_cancel.c_record_or_ticket_stat_second
                where t.ticket_id=p_ticket_id;

            exception
                when attempt_to_insert_null_into_not_null then

                    lazorenko_al.add_error_log(
        $$plsql_unit_owner||'.'||$$plsql_unit||'.'||utl_call_stack.subprogram(1)(2),
            '{"error":"' || sqlerrm ||'","value":"'
                     || p_patient_id
                     ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                     ||'"}'
                    );

                    dbms_output.put_line('запись внести невозможно - все поля должны быть заполнены');

                rollback;
                begin
                v_result:=lazorenko_al.t_result(result_value => 0);
                end;
                return v_result;

           end;

        else

            insert into lazorenko_al.records(record_id, record_stat_id, patient_id, ticket_id)
            values (default, lazorenko_al.pkg_write_or_cancel.c_record_or_ticket_stat_first, p_patient_id, p_ticket_id);

            update lazorenko_al.ticket t set t.ticket_stat_id=lazorenko_al.pkg_write_or_cancel.c_record_or_ticket_stat_second
            where t.ticket_id=p_ticket_id;

        end if;

      v_result:=lazorenko_al.t_result(result_value => 1);

   return v_result;

    end;

    function cancel_record(
        p_ticket_id in number
    )
    return  lazorenko_al.t_result  as
        v_result lazorenko_al.t_result;

        no_ticket_found exception;
        pragma exception_init (no_ticket_found, -20500);

    begin

            update lazorenko_al.ticket t set t.ticket_stat_id=lazorenko_al.pkg_write_or_cancel.c_record_or_ticket_stat_first
            where t.ticket_id=p_ticket_id;

            update lazorenko_al.records r set r.record_stat_id=lazorenko_al.pkg_write_or_cancel.c_record_or_ticket_stat_second
            where r.ticket_id=p_ticket_id;

        if sql%notfound then
        raise_application_error(-20500,'указан неверный талон');
        end if;

        v_result:=lazorenko_al.t_result(result_value  => 1);

        return v_result;

    exception
        when no_ticket_found then

            lazorenko_al.add_error_log(
        $$plsql_unit_owner||'.'||$$plsql_unit||'.'||utl_call_stack.subprogram(1)(2),
            '{"error":"' || sqlerrm
                      ||'","value":"' || p_ticket_id
                      ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                      ||'"}'
            );

            dbms_output.put_line('указан неверный талон');

        v_result:=lazorenko_al.t_result(result_value  => 0);

        return v_result;

    end;

end;




----------------------------------------------------ИСПОЛЬЗОВАНИЕ-------------------------------------------------------

--ОБЕ ФУНКЦИИ МОГУТ ВОЗВРАЩАТЬ 1 В СЛУЧАЕ УСПЕХА И 0 В СЛУЧАЕ ПРОВАЛА

--ЗАПИСЬ
declare
    v_patient number :=null;
    v_ticket number :=33;
    v_result lazorenko_al.t_result;
begin
   v_result:=lazorenko_al.pkg_write_or_cancel.write_to_records(
        p_patient_id => v_patient,
        p_ticket_id => v_ticket,
        p_need_handle => true
    );
    commit;
   dbms_output.put_line(v_result.result_value);
end;

--ОТМЕНА ЗАПИСИ
declare
    v_ticket number :=null;
    v_result lazorenko_al.t_result;
begin
   v_result:=lazorenko_al.pkg_write_or_cancel.cancel_record(
        p_ticket_id => v_ticket
    );
    commit;
   dbms_output.put_line(v_result.result_value);
end;



------------------------------------------------------------------------------------------------------------------------
-------------------------------------CHECK-ФУНКЦИЯ С ОБРАБОТКОЙ И ЛОГИРОВАНИЕМ ОШИБОК-----------------------------------
------------------------------------------------------------------------------------------------------------------------
create or replace function lazorenko_al.ticket_is_real(
    p_ticket_id in number
)
return boolean
as
    v_count number;

begin

    select t.ticket_id
    into v_count
    from lazorenko_al.ticket t
    where t.ticket_id=p_ticket_id;

    return v_count>0;

    exception
        when no_data_found
        then lazorenko_al.add_error_log(
    $$plsql_unit_owner||'.'||$$plsql_unit,
        '{"error":"' || sqlerrm
                  ||'","value":"' || p_ticket_id
                  ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                  ||'"}'
            );

            dbms_output.put_line('такого талона не существует');

    return false;

end;




create or replace function check_age(
    p_patient_id in number,
    p_spec_id in number
)
return boolean
as
    v_patient lazorenko_al.t_patient;
    v_age number;
    v_count number;

    e_wrong_age exception;
    pragma exception_init (e_wrong_age, -20400);

begin

    v_patient:=lazorenko_al.get_patient_info_by_id(p_patient_id);
    v_age:=lazorenko_al.calculate_age_from_date(v_patient.born_date);

    select count(*)
    into v_count
    from lazorenko_al.specialisation s
    where s.spec_id = p_spec_id
          and (s.min_age <= v_age or s.min_age is null)
          and (s.max_age >= v_age or s.max_age is null);

    if v_count=0 then
       raise_application_error (-20400, 'возраст пациента не соответствует возрасту специальности');
    end if;

    return v_count>0;

    exception

        when e_wrong_age then
            lazorenko_al.add_error_log(
    $$plsql_unit_owner||'.'||$$plsql_unit,
        '{"error":"' || sqlerrm
                  ||'","value":"' || p_patient_id
                  ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                  ||'"}'
            );

            dbms_output.put_line('возраст пациента не соответствует возрасту специальности');

    return false;

end;


create or replace function sex_check(
    p_patient_id in number,
    p_spec_id in number
)
return boolean
    as
    v_sex number;
    v_patient lazorenko_al.t_patient;
    v_count number;

    e_wrong_sex exception;
    pragma exception_init (e_wrong_sex, -20401);



begin

    v_patient:=lazorenko_al.get_patient_info_by_id(p_patient_id);
    v_sex:=v_patient.sex_id;
    select count(*)
    into v_count
    from lazorenko_al.specialisation s
    where s.spec_id=p_spec_id
          and (s.sex_id=v_sex or s.sex_id is null);

    if v_count=0 then
       raise_application_error (-20401, 'пол пациента не соответствует полу специальности');
    return v_count>0;
    end if;

    return v_count>0;

    exception
        when e_wrong_sex then
            lazorenko_al.add_error_log(
    $$plsql_unit_owner||'.'||$$plsql_unit,
        '{"error":"' || sqlerrm
                  ||'","value":"' || p_patient_id
                  ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                  ||'"}'
            );

            dbms_output.put_line('пол пациента не соответствует полу специальности');

    return false;

end;


create or replace function patient_doc_check(
    p_patient_id in number
)
return boolean
as
    v_count number;

    e_no_docs exception;
    pragma exception_init (e_no_docs, -20402);

begin
    select count(*)
    into v_count
    from lazorenko_al.documents_numbers dn
    where dn.patient_id=p_patient_id and dn.document_id=4
          and dn.value is not null;

    if v_count=0 then
       raise_application_error (-20402, 'отсутствуют данные по полису ОМС');
    return v_count>0;
    end if;

    return v_count>0;

    exception
        when e_no_docs then
            lazorenko_al.add_error_log(
    $$plsql_unit_owner||'.'||$$plsql_unit,
        '{"error":"' || sqlerrm
                  ||'","value":"' || p_patient_id
                  ||'","backtrace":"' || dbms_utility.format_error_backtrace()
                  ||'"}'
            );

            dbms_output.put_line('отсутствуют данные по полису ОМС');

    return false;

    end;


------------------------------------------------------------------------------------------------------------------------
-------ФУНКЦИЯ, ВКЛЮЧАЮЩАЯ В СЕБЯ РАЗЛИЧНЫЕ ПРОВЕРКИ ПЕРЕД ЗАПИСЬЮ------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

create or replace function lazorenko_al.check_for_accept_with_exceptions(
    p_ticket_id number,
    p_patient_id in number,
    p_spec_id number
)
return boolean
as
    v_result boolean := true;

    begin
    if (not lazorenko_al.ticket_is_real(
        p_ticket_id => p_ticket_id
        ))
    then v_result:=false;
    end if;

    if (not lazorenko_al.check_age(
        p_patient_id => p_patient_id,
        p_spec_id => p_spec_id
        ))
    then v_result:=false;
    end if;

    if (not lazorenko_al.sex_check(
        p_patient_id => p_patient_id,
        p_spec_id => p_spec_id
        ))
    then v_result:=false;
    end if;

    if (not lazorenko_al.patient_doc_check(
        p_patient_id => p_patient_id
        ))
    then v_result:=false;
    end if;

    return v_result;
    end;

declare
    v_check number;
begin
    v_check:=sys.diutil.bool_to_int(lazorenko_al.check_for_accept_with_exceptions(330, 7, 6));

    dbms_output.put_line(v_check);
end;

------------------------------------------------------------------------------------------------------------------------
----------------------ИТОГВАЯ ФУНКЦИЯ ЗАПИСИ ПОСЛЕ ПРОВЕРКИ УСЛОВИЙ-----------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

create or replace function lazorenko_al.accept_record_by_rules_with_exceptions(
    v_ticket_id number,
    v_patient_id number,
    v_spec_id number,
    v_need_handle boolean)
return  number as
    v_result lazorenko_al.t_result;
    begin
        if (lazorenko_al.check_for_accept_with_exceptions(
            p_ticket_id => v_ticket_id,
            p_patient_id => v_patient_id,
            p_spec_id => v_spec_id))

        then v_result:=lazorenko_al.pkg_write_or_cancel.write_to_records(
            p_patient_id => v_patient_id,
            p_ticket_id => v_ticket_id,
            p_need_handle => v_need_handle);

        else v_result:=lazorenko_al.t_result(result_value =>0);

        end if;

    return v_result.result_value;
    end;

--ПРИМЕНЕНИЕ ФУНКЦИИ

declare
    v_result lazorenko_al.t_result;
begin
    v_result:=lazorenko_al.t_result(result_value => lazorenko_al.accept_record_by_rules_with_exceptions(
    330, 7, 6, true));

    commit;
    dbms_output.put_line(v_result.result_value);
end;
