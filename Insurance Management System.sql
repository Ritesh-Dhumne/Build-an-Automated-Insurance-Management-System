create table customers (
customer_id serial primary key,   first_name varchar,  last_name varchar,	date_of_birth  date,	gender varchar ,	contact_number bigint,	email varchar,	address varchar,  aadhaar_number bigint,	pan_number varchar
)

create table agents(
agent_id  serial primary key,  first_name varchar,	last_name varchar,	contact_number bigint,	email varchar,	commission_rate real
)

create table policies(
policy_id  serial primary key,   policy_type varchar,	coverage_amount	int,	premium_amount	int,	start_date	date,	end_date date,		customer_id	int references customers(customer_id),	agent_id int references agents(agent_id), approved_by varchar
)

create table claims(
claim_id serial primary key,	 claim_date	date,	amount_claimed	int,	status	varchar,	policy_id	int references policies(policy_id),	approved_by  varchar
)

create table payments(
payment_id  serial primary key,     payment_date date ,	amount	int,	payment_method	varchar,	payment_uuid varchar, policy_id int references policies(policy_id)
)

copy customers from 'D:\SQL Project\Build-an-Automated-Insurance-Management-System\Build-an-Automated-Insurance-Management-System\customers.csv' delimiter ',' csv header;
copy agents from 'D:\SQL Project\Build-an-Automated-Insurance-Management-System\Build-an-Automated-Insurance-Management-System\agents.csv' delimiter ',' csv header;
copy policies from 'D:\SQL Project\Build-an-Automated-Insurance-Management-System\Build-an-Automated-Insurance-Management-System\policies.csv' delimiter ',' csv header;
copy claims from 'D:\SQL Project\Build-an-Automated-Insurance-Management-System\Build-an-Automated-Insurance-Management-System\claims.csv' delimiter ',' csv header;
copy payments from 'D:\SQL Project\Build-an-Automated-Insurance-Management-System\Build-an-Automated-Insurance-Management-System\payments.csv' delimiter ',' csv header;

/*
Step 3: SQL Queries and Procedures

*/

/*
1.Automated Claim Status Updates: Write a trigger or scheduled job that automatically updates the status 
  of claims based on conditions such as claim amount or random logic.
*/

create or replace function Claim_status_upd()
returns trigger as $$ 
begin
	if New.amount_claimed < 10000 then
		New.status = 'Approved';
	elseif New.amount_claimed > 200000 then 
	    New.status ='Rejected';
	else 
		New.status = 'Pending';
	end if;
	return new;
end;
$$ language plpgsql;

create or replace trigger claimstatus
before insert on claims
for each row 
execute function Claim_status_upd();

insert into claims (claim_id,claim_date,amount_claimed,policy_id,approved_by)
values (2003,'2025-01-15',9000,451,'Nakul Mehta')

select * from claims where claim_id = 2003;

/*
2.Generate Reports: Write queries to:
	List policies sold by each agent.
	
*/

select a.agent_id ,first_name || ' '|| last_name as agent_name,count(p.policy_id) as policy_sold
from agents a left join policies p on a.agent_id = p.agent_id
group by a.agent_id,agent_name 
order by policy_sold desc;

create or replace procedure policy_sold_by_agents (inout agentid int  default null ,inout agentname varchar default null ,inout policysold int default null )
language plpgsql as $$ 
begin
select a.agent_id ,first_name || ' '|| last_name as agent_name,count(p.policy_id) as policy_sold into agentid,agentname,policysold
from agents a left join policies p on a.agent_id = p.agent_id
group by a.agent_id,agent_name 
order by policy_sold desc;
end;
$$;

call policy_sold_by_agents()


--Display claims with different statuses.

select status,count(*) as policy_count from claims group by status;

--Show payment history per customer and policy.

select c.customer_id,first_name || ' ' || last_name as customer_name ,p.policy_id,policy_type ,payment_id, amount,payment_method
from customers c join policies p on c.customer_id = p.customer_id 
join payments pa on p.policy_id = pa.policy_id 

/*
: Advanced Automation Techniques
Triggers:
*/

--1.Auto-expiring policies: Create a trigger that automatically expires policies after the end date.

alter table policies add column isexpired boolean default 'False';

create or replace function expire_policy()
returns trigger as $$ 
begin 
if New.end_date < current_date then New.isexpired = 'True';
else New.isexpired = 'False';
end if;
return new;
end;
$$ language plpgsql;


create or replace trigger expiringpolicy
before insert or update on policies 
for each row 
execute function expire_policy()


insert into policies values (1001,'bike Ins', 300000,30000,'2025-04-16','2026-03-15',23,20,'Vijay Verma')

select * from policies where policy_id =1001;


--2.Preventing duplicate claims: Write a trigger to prevent customers from submitting duplicate claims for the same incident.

create or replace function prevent_duplicate()
returns trigger as $$
begin 
if exists (
select * from claims where policy_id = new.policy_id
and claim_date =new.claim_date
)then raise exception 'Duplicate claim not alowed';
end if;
return new;
end;
$$ language plpgsql;

create trigger check_duplicate
before insert on claims 
for each row 
execute function prevent_duplicate()

insert into claims values (2001,'2020-12-06',30000,'Rejected',537,'Rohan Gupta')


--3.Auto-calculating agent commissions: Write a trigger that automatically calculates and updates the commission earned by agents whenever a new policy is created.

create table agent_commisions(
commision_id serial primary key,
agent_id int references agents(agent_id),
policy_id int references policies(policy_id),
commision real,
rec_date timestamp default current_timestamp
)

create or replace function auto_commision_cal()
returns trigger as $$
declare rate real;
begin
select commission_rate into rate from agents where agent_id = new.agent_id;

insert into agent_commisions(agent_id,policy_id,commision) values
(new.agent_id,new.policy_id,new.premium_amount);

return new;
end;
$$ language plpgsql;

create or replace trigger commision_cal
after insert on policies
for each row 
execute function auto_commision_cal()

insert into policies values (1004,'Health',450000,4500,'2025-04-16','2026-04-15',30,21,'Gaurav Verma')

select * from agent_commisions

--4.Auto-approving claims below a threshold: If a claim is below a certain amount (e.g., ₹10,000), write a trigger to automatically approve it

CREATE OR REPLACE FUNCTION auto_approve_small_claims()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount_claimed < 10000 THEN
        NEW.status := 'Approved';
        -- Optionally, you can set approved_by as 'System'
        NEW.approved_by := 'System';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_auto_approve_claims
BEFORE INSERT ON claims
FOR EACH ROW
EXECUTE FUNCTION auto_approve_small_claims();



/*

Stored Procedures:

*/

--1.Automating policy renewals: Write a stored procedure to automatically renew policies that are expiring, if the customer has made full payments and has no outstanding claims.

CREATE OR REPLACE PROCEDURE renew_policies()
LANGUAGE plpgsql
AS $$
DECLARE
    pol RECORD;
    total_paid INT;
    pending_claims INT;
BEGIN
    FOR pol IN
        SELECT p.* FROM policies p
        WHERE p.end_date = CURRENT_DATE
    LOOP
        -- Total payments made for this policy
        SELECT COALESCE(SUM(amount), 0) INTO total_paid
        FROM payments
        WHERE policy_id = pol.policy_id;

        -- Pending claims count
        SELECT COUNT(*) INTO pending_claims
        FROM claims
        WHERE policy_id = pol.policy_id AND status = 'Pending';

        IF total_paid >= pol.premium_amount AND pending_claims = 0 THEN
            -- Renew policy: Extend dates by 1 year
            UPDATE policies
            SET start_date = pol.end_date,
                end_date = pol.end_date + INTERVAL '1 year'
            WHERE policy_id = pol.policy_id;
        END IF;
    END LOOP;
END;
$$;

CALL renew_policies();


--2.Automating payments: Create a stored procedure to automatically process recurring payments for policies that are paid in installments.


CREATE OR REPLACE PROCEDURE process_recurring_payments()
LANGUAGE plpgsql
AS $$
DECLARE
    pol RECORD;
    installment INT;
BEGIN
    FOR pol IN
        SELECT * FROM policies
        WHERE CURRENT_DATE BETWEEN start_date AND end_date
    LOOP
        -- Calculate monthly installment
        installment := pol.premium_amount / 12;

        -- Insert payment
        INSERT INTO payments (payment_date, amount, payment_method, payment_uuid, policy_id)
        VALUES (
            CURRENT_DATE,
            installment,
            'Auto-Debit',
            gen_random_uuid()::text,  -- Make sure the pgcrypto extension is enabled
            pol.policy_id
        );
    END LOOP;
END;
$$;

CALL process_recurring_payments();


--3.Dynamically generating reports: Implement a stored procedure that dynamically generates reports on the number of policies, claims, and payments processed each day.

create or replace procedure generate_report(inout fis_date date default null,inout last_date date default null)
language plpgsql as $$
declare
total_policies int;
total_claims int;
total_payments int;
begin 

select count(*) into total_policies from policies where start_date between fis_date and last_date;

select count(*) into total_claims from claims where claim_date between fis_date and last_date;

select count(*) into total_payments from payments where payment_date between fis_date and last_date;

raise exception 'Generated Report %,%,%',total_policies,total_claims,total_payments;

end;
$$;

call generate_report('2020-01-01','2022-12-31')

--Audit Tables:
--1.Tracking all changes in key tables: Implement audit tables to log any changes made to important tables such as Policies, Claims, and Payments. The audit tables will track what data was changed, when, and by whom.


create table audit_logs(log_id serial primary key ,
tablename varchar ,
operation varchar ,
operation_time timestamp default current_timestamp ,
login_user varchar default current_user,
olddata jsonb,
newdata jsonb
)


create or replace function audit_fun()
returns trigger as $$
begin
	if TG_OP = 'INSERT' then
	insert into audit_logs(tablename,operation,olddata,newdata) values (TG_Table_name,TG_OP,null,row_to_json(new));
	/* since we are inserting the data so we will not have the old data and it will be null*/
	
	elseif TG_OP = 'UPDATE' then
	 insert into  audit_logs(tablename,operation,olddata,newdata) values (TG_Table_name,TG_OP,row_to_json(old),row_to_json(new));
	
	elseif TG_OP = 'DELETE' then
	insert into  audit_logs(tablename,operation,olddata,newdata) values (TG_Table_name,TG_OP,row_to_json(old),null);
	/*since we are deleting the data so we will not have the new data and it will be null*/
	end if;
	/*delete insert update should be in capital */
	return new;
end;

$$ language plpgsql;

create or replace trigger audit_trig
after update or insert or delete on policies
for each statement
execute function audit_fun();

create or replace trigger audit_trig
after  update or insert or delete on claims
for each statement
execute function audit_fun();

create or replace trigger audit_trig
after  update or insert or delete on agents
for each statement
execute function audit_fun();

create or replace trigger audit_trig
after  update or insert or delete on customers
for each statement
execute function audit_fun();

